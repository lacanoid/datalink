/*
   pg_dlfuse - PostgreSQL SQL/MED Datalink File Filter for FUSE
   version 0.25.1231 (+ write support)

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
#include <sys/stat.h>
#include <sys/xattr.h>
#include <fuse.h>
#include <libpq-fe.h>

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

static PGresult *run_authorize(PGconn *conn, const char *path, const char *mode) {
	const char *paramValues[2] = { path, mode };

	if (mode) {
		return PQexecParams(conn,
			"SELECT datalink.dl_authorize($1,$2)",
			2,        // two params
			NULL,     // let PostgreSQL deduce types
			paramValues,
			NULL, NULL, 0);
	}
	return PQexecParams(conn,
		"SELECT datalink.dl_authorize($1)",
		1,        // one param
		NULL,     // let PostgreSQL deduce type
		paramValues,
		NULL, NULL, 0);
}

/*
 * authorize() calls datalink.dl_authorize(path) for read access,
 * or datalink.dl_authorize(path, mode) when mode is non-NULL
 * (e.g. mode = "w" for write access). Returns the real file
 * system path to use, or NULL if access was not authorized.
 *
 * If this thread's connection turns out to be broken (e.g. the
 * database was restarted), it is reset and the query is tried once
 * more. A query that fails while the connection is still healthy is
 * a real error and is not retried.
 *
 * Note for mode "w": if the connection breaks after the server ran
 * the query but before the answer arrived, the one-time write
 * authorization is used up and the retry returns NULL, so the open
 * is refused. It fails closed; a second write grant is never given.
 */
static char *authorize(const char *path, const char *mode) {
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

		res = run_authorize(conn, path, mode);
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

static int dl_getattr(const char *path, struct stat *stbuf,
                      struct fuse_file_info *fi) {
	(void) fi;
	memset(stbuf, 0, sizeof(struct stat));

	char *real_path = authorize(path, NULL);
	if (!real_path) return -ENOENT;

	int res = stat(real_path, stbuf);
	free(real_path);
	return (res == -1) ? -errno : 0;
}

static int dl_open(const char *path, struct fuse_file_info *fi) {
	/* writable access is requested via O_WRONLY / O_RDWR (with or
	   without O_APPEND/O_TRUNC) - anything else is treated as read */
	int want_write = (fi->flags & O_ACCMODE) != O_RDONLY;

	char *real_path = authorize(path, want_write ? "w" : NULL);
	if (!real_path) return want_write ? -EACCES : -ENOENT;

	/* preserve the caller's access mode and any append/trunc flags,
	   but never allow O_CREAT through this filter */
	int open_flags = fi->flags & ~O_CREAT;
	int fd = open(real_path, open_flags);
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
	char *real_path = authorize(path, NULL);
	if (!real_path) return -ENOENT;

	ssize_t res = getxattr(real_path, name, value, size);
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
		char *real_path = authorize(path, "w");
		if (!real_path) return -EACCES;

		res = truncate(real_path, size);
		free(real_path);
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

int main(int argc, char *argv[]) {
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

	return fuse_main(argc, argv, &dl_oper, NULL);
}
