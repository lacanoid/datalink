
SQL Scalar functions
--------------------

These are specified by the SQL/MED standard.

Most of these have been overloaded to work on text as well as datalinks. If argument is passed as text, it is implicitly converted to datalink first.

### dlurlcomplete(datalink)
Use `dlurlcomplete()` function to convert datalinks back to URLs. For READ ACCESS DB datalinks URL will contain read access token.
Tokens are generated when INTEGRITY ALL datalinks are stored in tables.

    mydb=# select dlurlcomplete(dlvalue('http://www.github.io/a/b/c/d/../../e'));
            dlurlcomplete      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    mydb=# select dlurlcomplete('http://www.github.io/a/b/c/d/../../e');
            dlurlcomplete      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    mydb=# create table t ( link datalink(122) ); 
    NOTICE:  DATALINK DDL:TRIGGER on t
    CREATE TABLE
    mydb=# insert into t values (dlvalue('/var/www/datalink/test1.txt')); 
    NOTICE:  DATALINK LINK:/var/www/datalink/test1.txt
    INSERT 0 1

    mydb=# select dlurlcomplete(link) from t;
                                  dlurlcomplete                              
    -------------------------------------------------------------------------
     file:///var/www/datalink/b6fd3d9b-45bb-400b-b2f5-fcd72c380434;test1.txt
    (1 row)

### dlurlcompleteonly(datalink)
Use `dlurlcompleteonly()` function to convert datalinks back to URLs. URL never contains access token.

    mydb=# select dlurlcompleteonly(dlvalue('http://www.github.io/a/b/c/d/../../e'));
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    mydb=# select dlurlcompleteonly('http://www.github.io/a/b/c/d/../../e');
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    postgres=# select dlurlcompleteonly(link) from t;
             dlurlcompleteonly          
    ------------------------------------
     file:///var/www/datalink/test1.txt
    (1 row)

### dlurlpath(datalink)
Use `dlurlpath()` function to get file path from datalink. File path may contain access token.

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

    mydb=# select dlurlpath(link) from t;
                                dlurlpath                             
    ------------------------------------------------------------------
     /var/www/datalink/b6fd3d9b-45bb-400b-b2f5-fcd72c380434;test1.txt
    (1 row)

### dlurlpathonly(datalink)
Use `dlurlpathonly()` function to get file path from datalink. File path never contains access token.

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

    mydb=# select dlurlpathonly(link) from t;
            dlurlpathonly        
    -----------------------------
     /var/www/datalink/test1.txt
    (1 row)

### dlurlscheme(datalink)
Use `dlurlscheme()` function to get URL scheme part of datalink.

    mydb=# select dlurlscheme(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlscheme 
    -------------
     HTTPS
    (1 row)

### dlurlserver(datalink)
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

### dlcomment(datalink)
Use `dlcomment()` function to get datalink comment.

    mydb=# select dlcomment(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar','URL','A comment...'));
      dlcomment 
    --------------
     A comment...
    (1 row)

This function is not in SQL standard, but is available in other implementations.

### dllinktype(datalink)
Use `dllinktype()` function to get datalink type, as specified or determined in `dlvalue()`.

    mydb=# select dllinktype(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
    dllinktype 
    ------------
     URL
    (1 row)

    mydb=# select dllinktype(dlvalue('/var/www/datalink/test1.txt'));
    dllinktype 
    ------------
     FS
    (1 row)

    mydb=# select dllinktype(dlvalue('test1.txt','www'));
    dllinktype 
    ------------
    www
    (1 row)

This function is not in SQL standard, but is available in other implementations.


Additional functions
====================

These are not specified by the SQL standard, but are provided for the user's convenience.
Thay are all in the `datalink` schema.

URI manipulation
----------------

### uri_get(uri, part)
Get a part of URI, returns text.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.

### uri_get(datalink, part)
Get a part of a datalink's URI, returns text.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.

### uri_set(uri, part, value text)
Set a part of URI to a value, returns new URI.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.


Web access
----------

### curl_get(url, header_only boolean)
Use CURL to fetch content from the World Wide Web.
If header_only is true then HEAD request is made instead of GET, returning only headers.

For URLs of scheme `file` and a non null server, the server name is taken to be a name of `postgres_fdw` foreign server.
If one is found and the extension `dblink` is installed then the request is passed on to the foreign server.
Datalink extension needs to be installed on the foreign server as well for this to work.
This features instantly removes a bunch of SQL one would have to write to do this.

This function is used to check for the existence of `INTEGRITY SELECTIVE` datalinks.

Reading files
-------------

### read_text(file_path [,position [,length] ] )
Read local file contents as text. Returns text.
If the file is linked with `READ ACCESS DB` access is checked first with `dl_authorize()`.
This implements access with filename-embedded read tokens as per SQL standard.
A user can alternatively have SELECT privilege on the directory to read file.

### read_text(datalink [,position [,length] ] )
Read datalink contents as text. Returns text.

### read_lines(file_path [,position] )
Read local file contents as lines of text.
Returns set of lines with line numbers and file offset.

### read_lines(datalink [,position] )
Read datalink contents as lines of text.
Returns set of lines with line numbers and file offset.
Currently works only for local files.


New file creation
------------------

### write_text(file_path , content text)
Write local file contents as text. 
File must not exist.
Returns number of bytes written.
User must have CREATE privilege on the directory.

### write_text(datalink , content text)
Write datalink contents as text. 
New version of file is created.
Returns new datalink, which can be used for update of a datalink column.


Compatibility functions
-----------------------

### fileexists(datalink)
Check if file exists.

### getlength(datalink)
Return file size in bytes.

### instr(datalink,text)
Search for a string in text file, returns offset where found.

### substr(datalink [,position [,length] ] )
Return substring of length from a file starting with offset.


Next
----
[Referential integrity](integrity.md)
