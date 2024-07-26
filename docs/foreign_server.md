[Datalink manual](README.md)

Foreign servers
===============

For URLs of scheme `file` and a non null server, the server name is taken to be a name of `postgres_fdw` foreign server.
If one is found and the extension `dblink` is installed then the request is passed on to the foreign server.
Datalink extension needs to be installed on the foreign server as well for this to work.

    mydb=# create extension postgres_fdw;
    CREATE EXTENSION
    mydb=# create server mydb foreign data wrapper postgres_fdw;
    CREATE SERVER
    mydb=# create user mapping for current_role server mydb;
    CREATE USER MAPPING
    mydb=# select body from datalink.curl_get('file://mydb/etc/issue');
             body        
     --------------------
      Ubuntu 23.10 \n \l

    
    (1 row)


[Datalink manual](README.md)
