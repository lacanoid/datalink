#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <libpq-fe.h>

char resolved_path[PATH_MAX];
int wstatus;

int main(int argc, char **argv) {
    PGresult *res;
    const char *paramValues[1];
    //    int lib_ver = PQlibVersion();
    char *conninfo = "service=datalinker";
    PGconn *conn = PQconnectdb(conninfo);

    // Connect to the database
    // conninfo is a string of keywords and values separated by spaces.
    // Create a connection

    // Check if the connection is successful
    if (PQstatus(conn) != CONNECTION_OK) {
        // If not successful, print the error message and finish the connection
        printf("Error while connecting to the database server: %s\n", PQerrorMessage(conn));

        // Finish the connection
        PQfinish(conn);

        // Exit the program
        exit(1);
    }

    /*
    // We have successfully established a connection to the database server
    printf("Connection Established\n");
    printf("Port: %s\n", PQport(conn));
    printf("Host: %s\n", PQhost(conn));
    printf("DBName: %s\n", PQdb(conn));
    */

    for(int i=1;i<argc;i++) {
        paramValues[0] = argv[i];
        if(realpath(argv[i],resolved_path)) {
            paramValues[0] = resolved_path;
        }
        
        res = PQexecParams(conn,
                        "select datalink.dl_authorize($1,true)",
                        1,       /* one param */
                        NULL,    /* let the backend deduce param type */
                        paramValues,
                        NULL,    /* don't need param lengths since text */
                        NULL,    /* default to all text params */
                        0);      /* ask for text results */

        if (PQresultStatus(res) == PGRES_TUPLES_OK) {
            char *path = PQgetvalue(res,0,0);
            if(strlen(path)>0) {
                // dl_authorize returns true filename if authorized
                // spawn a new cat to stream the content
                pid_t pid=fork();
                if(!pid) {
                    execl("/usr/bin/cat", "cat", path, NULL);
                } else {
                    pid_t w = waitpid(pid, &wstatus, WUNTRACED | WCONTINUED);
                    if (w == -1) {
                        perror("waitpid");
                        PQclear(res);
                        exit(EXIT_FAILURE);
                    }
                }
            } else {
                fprintf(stderr, "dlcat: %s: Datalink read permission denied\n", resolved_path);
                PQclear(res);
                exit(EXIT_FAILURE);
            }
        }
        else {
            fprintf(stderr, "SELECT failed: %s", PQerrorMessage(conn));
            PQclear(res);
        }
    }

    // Close the connection and free the memory
    PQfinish(conn);
    exit(EXIT_SUCCESS);
}
