#define _GNU_SOURCE
/*
   pg_dlfuse - PostgreSQL SQL/MED Datalink File Filter for FUSE
   version 0.25.1231 (+ write support)

   Access control is done by the database, in datalink.dl_authorize().
   A file can only be reached with a valid token in its file name:
     'f' - read access (stat, getxattr, open for reading)
     'w' - open for writing, authorized only once per file
   Directories can be stat'ed without a token, to be able to reach files.

   Build (libfuse 3):
     gcc -Wall -Wextra -I`pg_config --includedir` -D_FILE_OFFSET_BITS=64 \
         pg_dlfuse.c `pkg-config fuse3 --cflags --libs` -lpq -pthread -o pg_dlfuse
*/

#define FUSE_USE_VERSION 35

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include <pwd.h>
#include <grp.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/xattr.h>
#include <fuse.h>
#include <libpq-fe.h>

#if defined(__linux__) && defined(__has_include)
#  if __has_include(<linux/openat2.h>)
#    include <linux/openat2.h>
#  endif
#endif

char *conninfo = "service=pg_datalink application_name=pg_dlfuse";

/*
 * Every thread uses its own PGconn: a libpq connection must not be
 * used by several threads at once, and libfuse runs callbacks on a
 * pool of worker threads. The connection is created lazily the first
 * time a thread needs it and closed when the thread exits.
 */
static pthread_key_t conn_key;
static pthread_once_t conn_once = PTHREAD_ONCE_INIT;

static void conn_destroy(void *p) {
	if (p) PQfinish((PGconn *) p);
}

static void conn_key_init(void) {
	pthread_key_create(&conn_key, conn_destroy);
}

/* Returns this thread's connection, connecting if it has none yet.
   Returns NULL if the database cannot be reached (the next call
   tries again). */
static PGconn *get_conn(void) {
	pthread_once(&conn_once, conn_key_init);

	PGconn *conn = pthread_getspecific(conn_key);
	if (conn) return conn;

	conn = PQconnectdb(conninfo);
	if (PQstatus(conn) != CONNECTION_OK) {
		fprintf(stderr, "pg_dlfuse: connection to database failed: %s",
		        PQerrorMessage(conn));
		PQfinish(conn);
		return NULL;
	}
	pthread_setspecific(conn_key, conn);
	return conn;
}

static PGresult *run_authorize(PGconn *conn, const char *path, const char *op) {
	const char *paramValues[2] = { path, op };

	return PQexecParams(conn,
		"SELECT datalink.dl_authorize($1,$2::\"char\")",
		2,        // two params
		NULL,     // let PostgreSQL deduce types
		paramValues,
		NULL, NULL, 0);
}

/*
 * authorize() calls datalink.dl_authorize(path, op), op being 'f' for
 * read access or 'w' for write access. Returns the real file system
 * path to use, or NULL if access was not authorized.
 *
 * If this thread's connection turns out to be broken (e.g. the
 * database was restarted), it is reset and the query is tried once
 * more. A query that fails while the connection is still healthy is
 * a real error and is not retried.
 *
 * Note for op 'w': if the connection breaks after the server ran
 * the query but before the answer arrived, the one-time write
 * authorization is used up and the retry returns NULL, so the open
 * is refused. It fails closed; a second write grant is never given.
 */
static char *authorize(const char *path, char op) {
	const char opstr[2] = { op, '\0' };

	PGconn *conn = get_conn();
	if (!conn) return NULL;

	PGresult *res = NULL;
	for (int attempt = 0; attempt < 2; attempt++) {
		if (PQstatus(conn) != CONNECTION_OK) {
			PQreset(conn);
			if (PQstatus(conn) != CONNECTION_OK) {
				fprintf(stderr, "pg_dlfuse: reconnect failed: %s",
				        PQerrorMessage(conn));
				return NULL;
			}
		}

		res = run_authorize(conn, path, opstr);
		if (PQresultStatus(res) == PGRES_TUPLES_OK) break;

		PQclear(res);
		res = NULL;
		if (PQstatus(conn) == CONNECTION_OK) return NULL;  /* real error */
	}
	if (!res) return NULL;

	if (PQntuples(res) == 0 || PQgetisnull(res, 0, 0)) {
		PQclear(res);
		return NULL;
	}

	char *authorized_path = strdup(PQgetvalue(res, 0, 0));
	PQclear(res);
	return authorized_path;
}

/* Only these open flags are passed on. This also leaves out O_CREAT:
   files are never created through this filter. */
#define OPEN_FLAGS_MASK \
  (O_ACCMODE | O_APPEND | O_TRUNC | O_SYNC | O_DSYNC | O_NONBLOCK | O_NOATIME)

/*
 * Open a file without following symbolic links, so that a link inside
 * a prefix cannot lead out of it. With openat2() (Linux 5.6) no symlink
 * is followed anywhere in the path; on older kernels only a symlink as
 * the last path component is refused. If your prefixes lie behind
 * symlinked directories (e.g. /var/run), this refuses them as well.
 */
static int open_nosymlinks(const char *path, int flags) {
#if defined(SYS_openat2) && defined(RESOLVE_NO_SYMLINKS)
	struct open_how how;
	memset(&how, 0, sizeof(how));
	how.flags = flags | O_CLOEXEC;
	how.resolve = RESOLVE_NO_SYMLINKS;

	int fd = syscall(SYS_openat2, AT_FDCWD, path, &how, sizeof(how));
	if (fd != -1 || errno != ENOSYS) return fd;
#endif
	return open(path, flags | O_NOFOLLOW | O_CLOEXEC);
}

static int dl_getattr(const char *path, struct stat *stbuf,
                      struct fuse_file_info *fi) {
	(void) fi;
	memset(stbuf, 0, sizeof(struct stat));

	char *real_path = authorize(path, 'f');
	if (!real_path) return -ENOENT;

	/* a symlink as the file itself is not followed */
	int res = lstat(real_path, stbuf);
	free(real_path);
	return (res == -1) ? -errno : 0;
}

static int dl_open(const char *path, struct fuse_file_info *fi) {
	/* writable access is requested via O_WRONLY / O_RDWR (with or
	   without O_APPEND/O_TRUNC) - anything else is treated as read */
	int want_write = (fi->flags & O_ACCMODE) != O_RDONLY;

	char *real_path = authorize(path, want_write ? 'w' : 'f');
	if (!real_path) return -EACCES;

	/* preserve the caller's access mode and any append/trunc flags */
	int fd = open_nosymlinks(real_path, fi->flags & OPEN_FLAGS_MASK);
	free(real_path);
	if (fd == -1) return -errno;

	/* remove write permission from the file */
	if (want_write) {
	  struct stat st;
	  if (fstat(fd, &st) == -1 ||
	      fchmod(fd, (st.st_mode & 07777) & ~(S_IWUSR | S_IWGRP | S_IWOTH)) == -1) {
	    int err = errno;
	    close(fd);
	    return -err;
	  }
	}

	fi->fh = fd;
	return 0;
}

static int dl_read(const char *path, char *buf, size_t size, off_t offset,
                    struct fuse_file_info *fi) {
	(void) path;
	int res = pread(fi->fh, buf, size, offset);
	return (res == -1) ? -errno : res;
}

static int dl_write(const char *path, const char *buf, size_t size,
                     off_t offset, struct fuse_file_info *fi) {
	(void) path;
	int res = pwrite(fi->fh, buf, size, offset);
	return (res == -1) ? -errno : res;
}

static int dl_release(const char *path, struct fuse_file_info *fi) {
	(void) path;
	close(fi->fh);
	return 0;
}

/*
 * flush() may be called more than once per open() (e.g. if the
 * process dup()'d the fd before closing each copy), so it must not
 * actually close fi->fh. Flushing via close(dup(fd)) is the usual
 * FUSE idiom: it forces any buffered writes for this fd out and
 * surfaces write-back errors (e.g. from NFS) without releasing fh.
 */
static int dl_flush(const char *path, struct fuse_file_info *fi) {
	(void) path;
	int res = close(dup(fi->fh));
	return (res == -1) ? -errno : 0;
}

static int dl_fsync(const char *path, int isdatasync, struct fuse_file_info *fi) {
	(void) path;
	int res = isdatasync ? fdatasync(fi->fh) : fsync(fi->fh);
	return (res == -1) ? -errno : 0;
}

/*
 * GETXATTR: read an extended attribute of the underlying real file.
 * Read-only access is enough. As with the FUSE/getxattr(2) contract,
 * size == 0 asks only for the attribute's size.
 */
static int dl_getxattr(const char *path, const char *name,
                       char *value, size_t size) {
	char *real_path = authorize(path, 'f');
	if (!real_path) return -ENOENT;

	ssize_t res = lgetxattr(real_path, name, value, size);
	free(real_path);
	return (res == -1) ? -errno : (int) res;
}

/*
 * TRUNCATE (FUSE 3 API): one callback for both cases.
 *
 * When called on an open file (ftruncate(2), or O_TRUNC), libfuse
 * passes fi: the file was already authorized for write at open() time,
 * so we truncate the fd directly. Calling authorize(path, "w") again
 * would return NULL, since a file can only be authorized for writing
 * once.
 *
 * When called by path only (truncate(2), fi == NULL) there is no open
 * file, so this is the one write authorization for the file.
 *
 * libfuse 3 enables FUSE_CAP_ATOMIC_O_TRUNC by default, so O_TRUNC is
 * passed to dl_open() (and on to open()) and does not arrive here as a
 * separate truncate() that would use up the write authorization.
 */
static int dl_truncate(const char *path, off_t size, struct fuse_file_info *fi) {
	int res;

	if (fi) {
		res = ftruncate(fi->fh, size);
	} else {
		char *real_path = authorize(path, 'w');
		if (!real_path) return -EACCES;

		int fd = open_nosymlinks(real_path, O_WRONLY);
		free(real_path);
		if (fd == -1) return -errno;

		res = ftruncate(fd, size);
		int err = errno;
		close(fd);
		errno = err;
	}
	return (res == -1) ? -errno : 0;
}

static const struct fuse_operations dl_oper = {
  .getattr = dl_getattr,
  .getxattr = dl_getxattr,
  .open    = dl_open,
  .read    = dl_read,
  .write   = dl_write,
  .truncate = dl_truncate,
  .flush   = dl_flush,
  .fsync   = dl_fsync,
  .release = dl_release,
};

/* The daemon must run as this unix user, and all files are accessed
   with its permissions. */
#define RUN_USER "postgres"

/*
 * Make sure the process runs as RUN_USER, with real, effective and
 * saved user and group ids all set to that user, so no root identity
 * is left over that could be regained later.
 *
 *  - effective uid is root: switch to RUN_USER (supplementary groups,
 *    gid, uid) permanently.
 *  - effective uid is already RUN_USER (possibly with a leftover real
 *    or saved uid, e.g. from a setuid binary): clean up the real and
 *    saved uids.
 *  - anyone else is refused, as the files could not be accessed with
 *    the right permissions.
 */
static int run_as_user(const char *name) {
	struct passwd *pw = getpwnam(name);
	if (!pw) {
		fprintf(stderr, "pg_dlfuse: unix user \"%s\" does not exist\n", name);
		return -1;
	}

	uid_t ruid, euid, suid;
	gid_t rgid, egid, sgid;
	if (getresuid(&ruid, &euid, &suid) == -1 ||
	    getresgid(&rgid, &egid, &sgid) == -1) {
		fprintf(stderr, "pg_dlfuse: cannot determine current user: %s\n",
		        strerror(errno));
		return -1;
	}

	if (euid == 0) {
		if (initgroups(name, pw->pw_gid) == -1 ||
		    setresgid(pw->pw_gid, pw->pw_gid, pw->pw_gid) == -1 ||
		    setresuid(pw->pw_uid, pw->pw_uid, pw->pw_uid) == -1) {
			fprintf(stderr, "pg_dlfuse: cannot switch to user \"%s\": %s\n",
			        name, strerror(errno));
			return -1;
		}
	} else if (euid == pw->pw_uid) {
		if (setresuid(pw->pw_uid, pw->pw_uid, pw->pw_uid) == -1) {
			fprintf(stderr, "pg_dlfuse: cannot clean up user ids: %s\n",
			        strerror(errno));
			return -1;
		}
	} else {
		fprintf(stderr, "pg_dlfuse: must be run as user \"%s\" or as root "
		        "(ruid=%d euid=%d suid=%d)\n",
		        name, (int) ruid, (int) euid, (int) suid);
		return -1;
	}

	/* verify the result: nothing but RUN_USER may be left */
	if (getresuid(&ruid, &euid, &suid) == -1 ||
	    ruid != pw->pw_uid || euid != pw->pw_uid || suid != pw->pw_uid ||
	    setuid(0) == 0) {
		fprintf(stderr, "pg_dlfuse: failed to run as user \"%s\" "
		        "(ruid=%d euid=%d suid=%d)\n",
		        name, (int) ruid, (int) euid, (int) suid);
		return -1;
	}

	/* let libpq find ~/.pg_service.conf of RUN_USER */
	setenv("HOME", pw->pw_dir, 1);
	setenv("USER", pw->pw_name, 1);
	setenv("LOGNAME", pw->pw_name, 1);
	return 0;
}

int main(int argc, char *argv[]) {
	if (run_as_user(RUN_USER) == -1) return 1;

	/* Check at startup that the database is reachable, then close the
	   connection again: worker threads open their own, and a libpq
	   connection must not be carried across fuse_main()'s fork. */
	PGconn *test = PQconnectdb(conninfo);
	if (PQstatus(test) != CONNECTION_OK) {
		fprintf(stderr, "Connection to database failed: %s\n", PQerrorMessage(test));
		PQfinish(test);
		return 1;
	}
	PQfinish(test);

	/* Always run in the foreground with allow_other. The only thing the
	   command line can change is the mount point, which defaults to
	   /dlfs. Other arguments (e.g. -o options) are passed on to libfuse. */
	char **fargv = malloc((argc + 6) * sizeof(char *));
	if (!fargv) return 1;

	int fargc = 0;
	int have_mountpoint = 0;
	fargv[fargc++] = argv[0];
	fargv[fargc++] = "-f";
	fargv[fargc++] = "-o";
	fargv[fargc++] = "allow_other";

	for (int i = 1; i < argc; i++) {
		fargv[fargc++] = argv[i];
		if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
			fargv[fargc++] = argv[++i];      /* value of -o */
		} else if (argv[i][0] != '-') {
			have_mountpoint = 1;
		}
	}
	if (!have_mountpoint) fargv[fargc++] = "/dlfs";
	fargv[fargc] = NULL;

	return fuse_main(fargc, fargv, &dl_oper, NULL);
}
