Here are some examples on how to use datalink

Creating datalink values
------------------------

You can create datalink values from text URLs by using `dlvalue()` function.

    mydb=# select dlvalue('http://www.github.io/');
                  dlvalue              
    ----------------------------------
     {"url": "http://www.github.io/"}
    (1 row)

Note that datalinks are internally represented as JSONB values.
One can also think of datalinks as 'bookmarks' to internet resources.

URLs are checked for syntax and wrong ones throw errors.

    mydb=# select dlvalue('foo bar');
    ERROR:  invalid input syntax for type uri at or near " bar"

URLs are normalized before they are converted to datalinks, so things like . and .. are resolved.

    mydb=# select dlvalue('http://www.github.io/a/b/c/d/../../e');
                    dlvalue                
    ---------------------------------------
     {"url": "http://www.github.io/a/b/e"}
    (1 row)

You can also use `dlvalue()` with absolute paths for file links.

    mydb=# select dlvalue('/var/www/datalink/index.html');
                        dlvalue                     
    ------------------------------------------------
     {"url": "file:///var/www/datalink/index.html"}
    (1 row)

    mydb=# select dlvalue('/var/www/datalink/index.html','FS');
                        dlvalue                     
    ------------------------------------------------
     {"url": "file:///var/www/datalink/index.html"}
    (1 row)

    mydb=# select dlvalue('file:///var/www/datalink/index.html');
                        dlvalue                     
    ------------------------------------------------
     {"url": "file:///var/www/datalink/index.html"}
    (1 row)


Datalink functions
------------------

Use `dlurlcomplete()` and `dlurlcompleteonly()` functions to convert datalinks back to URLs.

    mydb=# select dlurlcompleteonly(dlvalue('http://www.github.io/a/b/c/d/../../e'));
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e

    mydb=# select dlurlcompleteonly('http://www.github.io/a/b/c/d/../../e');
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

Use `dlurlpath()` and `dlurlpathonly()` functions to get file path from datalink.

    mydb=# select dlurlpathonly(dlvalue('/var/www/datalink/index.html'));
             dlurlpathonly         
    ------------------------------
     /var/www/datalink/index.html
    (1 row)

    mydb=# select dlurlpathonly(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlpathonly 
    ---------------
     /foo/bar
    (1 row)

    mydb=# select dlurlpath(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlpath 
    -----------
     /foo/bar
    (1 row)
    
    mydb=# select dlurlpath('https://user:password@www.gitgub.io:1234/foo/bar');
     dlurlpath 
    -----------
     /foo/bar
    (1 row)

Use `dlurlscheme()` function to get URL scheme part of datalink.

    mydb=# select dlurlscheme(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlscheme 
    -------------
     https
    (1 row)

Use `dlurlserver()` function to get URL server part of datalink.
This does not include username and password if they are present in URL.

    mydb=# select dlurlserver(dlvalue('https://user:password@www.github.io:1234/foo/bar'));
      dlurlserver  
    ---------------
     www.github.io
    (1 row)

    mydb=# select dlurlserver('https://user:password@www.github.io:1234/foo/bar');
      dlurlserver  
    ---------------
     www.github.io
    (1 row)

Referential integrity
---------------------

One can use datalinks to check whether resources pointed to by URLs exist.

For this, one must first create some table with datalink column with integrity='SELECTIVE'.

    mydb=# create table my_table (link datalink);
    CREATE TABLE
    mydb=# select * from datalink.columns where table_name='my_table';
     table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
     my_table   | link        | FILE         | SELECTIVE | FS          | FS           | NO       | NONE
    (1 row)

One can change link control options for a column with a SQL UPDATE statement.
Please note that currently only the super user can change column options.

    mydb=# update datalink.columns set integrity='SELECTIVE' where table_name='my_table';
    UPDATE 1

Now one can proceed to insert some datalinks.

    mydb=# insert into my_table values (dlvalue('http://www.ljudmila.org'));
    INSERT 0 1
    
    mydb=# insert into my_table values (dlvalue('http://www.ljudmila.org/foo'));
    INSERT 0 1
    
Datalinks are accessed via CURL with HEAD request as they are inserted.
If CURL request fails, exception is raised, transaction aborted and no value is inserted.

    mydb=# insert into my_table values (dlvalue('http://www.ljudmila2.org'));
    ERROR:  datalink exception - referenced file does not exist
    DETAIL:  (6) Couldn't resolve host name
    HINT:  make sure referenced file actually exists
    
    mydb=# insert into my_table values (dlvalue('https://www.ljudmila.org'));
    ERROR:  datalink exception - referenced file does not exist    
    DETAIL:  (60) Peer certificate cannot be authenticated with given CA certificates
    HINT:  make sure referenced file actually exists

Note that this work equally well for files.

    mydb=# insert into my_table values (dlvalue('/etc/issue'));
    INSERT 0 1

    mydb=# insert into my_table values (dlvalue('/etc/issue2'));
    ERROR:  datalink exception - referenced file does not exist
    DETAIL:  (37) Couldn't read a file:// file
    HINT:  make sure referenced file actually exists

    mydb=# table my_table;
                           link                        
    ---------------------------------------------------
     {"rc": 200, "url": "http://www.ljudmila.org"}
     {"rc": 404, "url": "http://www.ljudmila.org/foo"}
     {"url": "file:///etc/issue"}
(3 rows)







