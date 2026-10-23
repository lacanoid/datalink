/*
   pg_dlfuse - PostgreSQL SQL/MED Datalink File Filter for FUSE
   version 0.25.1231 (+ write support)
*/

#define FUSE_USE_VERSION 35

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <fuse.h>
#include <libpq-fe.h>

char *conninfo = "service=pg_datalink application_name=pg_dlfuse";
static PGconn *conn;

/*
 * authorize() calls datalink.dl_authorize(path) for read access,
 * or datalink.dl_authorize(path, mode) when mode is non-NULL
 * (e.g. mode = "w" for write access). Returns the real file
 * system path to use, or NULL if access was not authorized.
 */
static char *authorize(const char *path, const char *mode) {
	const char *paramValues[2] = { path, mode };
	PGresult *res;

	if (mode) {
		res = PQexecParams(conn,
			"SELECT datalink.dl_authorize($1,$2)",
			2,        // two params
			NULL,     // let PostgreSQL deduce types
			paramValues,
			NULL, NULL, 0);
	} else {
		res = PQexecParams(conn,
			"SELECT datalink.dl_authorize($1)",
			1,        // one param
			NULL,     // let PostgreSQL deduce type
			paramValues,
			NULL, NULL, 0);
	}

	if (PQresultStatus(res) != PGRES_TUPLES_OK) {
		PQclear(res);
		return NULL;
	}
	if (PQntuples(res) == 0 || PQgetisnull(res, 0, 0)) {
		PQclear(res);
		return NULL;
	}

	char *authorized_path = strdup(PQgetvalue(res, 0, 0));
	PQclear(res);
	return authorized_path;
}

static int dl_getattr(const char *path, struct stat *stbuf) {
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

static const struct fuse_operations dl_oper = {
  .getattr = dl_getattr,
  .getxattr = dl_getxattr,
  .open    = dl_open,
  .read    = dl_read,
  .write   = dl_write,
  .flush   = dl_flush,
  .fsync   = dl_fsync,
  .release = dl_release,
};

int main(int argc, char *argv[]) {
	conn = PQconnectdb(conninfo);
	if (PQstatus(conn) != CONNECTION_OK) {
		fprintf(stderr, "Connection to database failed: %s\n", PQerrorMessage(conn));
		PQfinish(conn);
		return 1;
	}

	int ret = fuse_main(argc, argv, &dl_oper, NULL);
	PQfinish(conn);
	return ret;
}
