Selective referential integrity
-------------------------------

One can use datalinks to check whether resources pointed to by URLs exist.

For this, one must first create a table with a column of type datalink.

    mydb=# create table my_table (link datalink);
    CREATE TABLE
    mydb=# select * from datalink.columns where table_name='my_table';
     table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
     my_table   | link        | NO           | NONE      | FS          | FS           | NO       | NONE
    (1 row)

Datalink columns are created by default without *link control* with *integrity* option set to `NONE`.
Datalinks are only checked for valid URL syntax but not processed further.

To enable integrity checks set integrity to `SELECTIVE` for this column.
One can change link control options for a column with an SQL UPDATE DATALINK.COLUMNS statement.
Please note that currently only the super user can change column options.

    mydb=# update datalink.columns set integrity='SELECTIVE' where table_name='my_table';
    UPDATE 1
    mydb=# select * from datalink.columns where table_name='my_table';
     table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
     my_table   | link        | FILE         | SELECTIVE | FS          | FS           | NO       | NONE
    (1 row)

Now one can proceed to insert some datalinks.

    mydb=# insert into my_table values (dlvalue('http://www.ljudmila.org'));
    INSERT 0 1
    
    mydb=# insert into my_table values (dlvalue('http://www.ljudmila.org/foo'));
    INSERT 0 1
    
Datalinks are checked via [CURL](https://curl.se/) with HEAD request as they are inserted or updated.
CURL [supports a wide range of protocols](https://curl.se/docs/comparison-table.html).
If CURL request fails, exception is raised and transaction is aborted.

    mydb=# insert into my_table values (dlvalue('http://www.ljudmila2.org'));
    ERROR:  datalink exception - referenced file does not exist
    DETAIL:  curl error 6 - Couldn't resolve host name
    HINT:  make sure referenced file actually exists
    
    mydb=# insert into my_table values (dlvalue('https://www.ljudmila.org'));
    ERROR:  datalink exception - referenced file does not exist    
    DETAIL:  curl error 60 - Peer certificate cannot be authenticated with given CA certificates
    HINT:  make sure referenced file actually exists

Note that this works equally well for files.

    mydb=# insert into my_table values (dlvalue('/etc/issue'));
    INSERT 0 1

    mydb=# insert into my_table values (dlvalue('/etc/issue2'));
    ERROR:  datalink exception - referenced file does not exist
    DETAIL:  curl error 37 - Couldn't read a file:// file
    HINT:  make sure referenced file actually exists

    mydb=# table my_table;
                           link                        
    ---------------------------------------------------
     {"rc": 200, "url": "http://www.ljudmila.org"}
     {"rc": 404, "url": "http://www.ljudmila.org/foo"}
     {"url": "file:///etc/issue"}
     
Note that successful checks for web datalinks do not mean that the the web page actually exists.
[HTTP response code](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes) is stored in the resulting datalink so that one can check further.
`404 NOT FOUND` errors were successfully inserted in the above example, because HTTP server returned a valid response.

After values are stored, no further checks are done.

Full referential integrity
--------------------------

Full referential integrity provides a base for tighter coupling of files and SQL environment. 
It can optionally prevent files from being changed, renamed or deleted, even by root.
It works only with local files with datalinks with URL scheme `file`.

To enable full referential integrity set integrity to `ALL` for this column.

    mydb=# update datalink.columns set integrity='ALL' where table_name='my_table';
    UPDATE 1
    mydb=# select * from datalink.columns where table_name='my_table';
     table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
     my_table   | link        | FILE         | ALL       | FS          | FS           | NO       | NONE
    (1 row)

With full referential integrity each link can be stored (linked) only once, insuring uniqueness among links across the whole database.
Once a datalink to a file is stored somewhere, the file is said to be *linked* and cannot be linked again until unlinked first.

For security reasons files are restricted to a set of directories or *volumes*. 
These are configured externally to postgres, using `pg_datalinker` command.
By default, volume `/var/www/datalink/` is created.

    mydb=# insert into my_table values (dlvalue('http://www.ljudmila.org'));
    ERROR:  INTEGRITY ALL can only be used with file URLs
    DETAIL:  http://www.ljudmila.org
    HINT:  make sure you are using a file: URL scheme

    mydb=# insert into my_table values (dlvalue('/etc/issue'));
    ERROR:  datalink exception - invalid datalink value
    DETAIL:  unknown file volume (prefix) in /etc/issue
    HINT:  run "pg_datalinker add" to add volumes

    mydb=# insert into my_table values (dlvalue('/var/www/datalink/test1.txt'));
    INSERT 0 1

Datalinks are assigned unique tokens as they are stored.

    mydb=# select * from my_table ;
                                                  link                                              
    ------------------------------------------------------------------------------------------------
     {"url": "file:///var/www/datalink/test1.txt", "token": "e56b96cb-6e15-4ed5-83cd-611e06877826"}
    (1 row)
    
One can see all currently linked files in `datalink.linked_files` view.

    mydb=# select * from datalink.linked_files ;
                path             | state | read | write | recovery | on_unlink | regclass | attname | owner | err 
    -----------------------------+-------+------+-------+----------+-----------+----------+---------+-------+-----
     /var/www/datalink/test1.txt | LINK  | FS   | FS    | NO       | NONE      | my_table | link    | ziga  | 
    (1 row)

Full referential integrity is meant to be supported by [pg_datalinker](pg_datalinker.md), a separate process coupled with postgres
to perform file operations on datalinks. Further settings require its use to be effective. Postgres server process by itself does
not have high enough privileges to change file permissions nor does extension perform any file changes by itself. It is all done by
the datalinker process.

Next: [Access control](access.md)