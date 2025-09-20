#define FUSE_USE_VERSION 35

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <fuse.h>
#include <libpq-fe.h>

char *conninfo = "service=pg_datalink application_name=pg_dlfuse";
static PGconn *conn;

static char *authorize(const char *path) {
    const char *paramValues[1] = { path };
    PGresult *res = PQexecParams(conn,
        "SELECT datalink.dl_authorize($1)",
        1,       // one param
        NULL,    // let PostgreSQL deduce type
        paramValues,
        NULL, NULL, 0);

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

static int pg_getattr(const char *path, struct stat *stbuf) {
    memset(stbuf, 0, sizeof(struct stat));

    char *real_path = authorize(path);
    if (!real_path) return -ENOENT;

    int res = stat(real_path, stbuf);
    free(real_path);

    return (res == -1) ? -errno : 0;
}

static int pg_open(const char *path, struct fuse_file_info *fi) {
    char *real_path = authorize(path);
    if (!real_path) return -EACCES;

    int fd = open(real_path, O_RDONLY);
    free(real_path);

    if (fd == -1) return -errno;

    fi->fh = fd;
    return 0;
}

static int pg_read(const char *path, char *buf, size_t size, off_t offset,
                   struct fuse_file_info *fi) {
    (void) path;

    int res = pread(fi->fh, buf, size, offset);
    return (res == -1) ? -errno : res;
}

static int pg_release(const char *path, struct fuse_file_info *fi) {
    (void) path;
    close(fi->fh);
    return 0;
}

static const struct fuse_operations pg_oper = {
    .getattr = pg_getattr,
    .open = pg_open,
    .read = pg_read,
    .release = pg_release,
};

int main(int argc, char *argv[]) {
    conn = PQconnectdb(conninfo);
    if (PQstatus(conn) != CONNECTION_OK) {
        fprintf(stderr, "Connection to database failed: %s\n", PQerrorMessage(conn));
        PQfinish(conn);
        return 1;
    }

    int ret = fuse_main(argc, argv, &pg_oper, NULL);

    PQfinish(conn);
    return ret;
}

