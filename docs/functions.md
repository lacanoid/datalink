[Datalink manual](README.md)

SQL Datalink constructors
-------------------------

### dlvalue( address text [ , link_type text [ , comment text ] ] ) → datalink

Make a datalink by specifying file `address`.

Address depends on `link_type`. Internally, address is always stored as URL.

For link type `URL`, address is specified as URL: 

    mydb=# select dlvalue('http://www.github.org','URL');
                dlvalue             
    --------------------------------
     {"a": "http://www.github.org"}
    (1 row)

For link type `FS`, address is specified as absolute file path (beginning with /):

    mydb=# select dlvalue('/var/www/datalink/test1.txt','FS');
                      dlvalue                   
    ---------------------------------------------
     {"a": "file:///var/www/datalink/test1.txt"}
    (1 row)

If link type is NULL or ommitted, then it is auto-detected from `address`:

    mydb=# select dlvalue('http://www.github.org');
                 dlvalue             
    --------------------------------
     {"a": "http://www.github.org"}
    (1 row)

    mydb=# select dlvalue('/var/www/datalink/test1.txt');
                      dlvalue                   
    ---------------------------------------------
     {"a": "file:///var/www/datalink/test1.txt"}
    (1 row)

When link type is equal to some `dirname` in table `datalink.directory` 
then `address` is taken to be relative to that directory:

    postgres=# select dlvalue('test1.txt','www');
                            dlvalue                         
    ---------------------------------------------------------
     {"a": "file:///var/www/datalink/test1.txt", "t": "www"}
    (1 row)

### dlvalue( address text [ , base datalink [ , comment text ] ] ) → datalink

Make a datalink, relative to another datalink.

    =# select dlvalue('style.css',dlvalue('http://www.github.org/index.html'));
                     dlvalue                  
    ------------------------------------------
     {"a": "http://www.github.org/style.css"}
    (1 row)

### dlpreviouscopy( datalink ) → datalink

Establish token value for a datalink, either by looking at the token embedded in the URL or by generating a new one.

### dlnewcopy( datalink [ , has_token ] ) → datalink

Generate a new token value for a datalink. This is used for indicating that the file contents have changed.
If `has_token` > 0 then the previous token will also be stored in a datalink as write token for update.

SQL Datalink scalar functions
-----------------------------

These are specified by the SQL/MED standard.

Most of these have been overloaded to work on text as well as datalinks. If argument is passed as text, it is implicitly converted to datalink first.

### dlurlcomplete( datalink ) → text

Use `dlurlcomplete()` function to convert datalinks back to URLs. 

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

For READ ACCESS DB datalinks URL will contain read access token.
Tokens are generated when INTEGRITY ALL datalinks are stored in tables and are used to authorize read access to the file content.

    mydb=# create table t ( link datalink(52) ); 
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

### dlurlcompleteonly( datalink ) → text

Use `dlurlcompleteonly()` function to convert datalinks back to URLs. URL never contains access token.
The function also omits any `fragment` part of the URL (stuff after #)

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

    mydb=# select dlurlcompleteonly(link) from t;
             dlurlcompleteonly          
    ------------------------------------
     file:///var/www/datalink/test1.txt
    (1 row)

### dlurlpath( datalink ) → text

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

### dlurlpathonly( datalink ) → text

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

### dlurlscheme( datalink ) → text

Use `dlurlscheme()` function to get URL scheme part of datalink.

    mydb=# select dlurlscheme(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlscheme 
    -------------
     HTTPS
    (1 row)

### dlurlserver( datalink ) → text

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

### dlcomment( datalink ) → text

Use `dlcomment()` function to get datalink comment.

    mydb=# select dlcomment(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar','URL','A comment...'));
      dlcomment 
    --------------
     A comment...
    (1 row)

This function is not in SQL standard, but is available in other implementations.

### dllinktype( datalink ) → text

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

### uri_get( uri , part ) → text

Get a part of URI, returns text.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.

### uri_get( datalink , part ) → text

Get a part of a datalink's URI, returns text.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.

### uri_set( uri , part , value text ) → text

Set a part of URI to a value, returns new URI.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.


Web access
----------

### curl_get( url text, header_only boolean ) → record

Use CURL to fetch content from the World Wide Web.

    mydb=# select * from datalink.curl_get('http://localhost/datalink/test1.txt');
                     url                 | ok | rc  | body  | error | elapsed  
    -------------------------------------+----+-----+-------+-------+----------
     http://localhost/datalink/test1.txt | t  | 200 | Hello+|       | 0.019225
                                         |    |     |       |       | 
    (1 row)


If `header_only` is true then HEAD request is made instead of GET, returning only headers.
This is used to check for the existence of `INTEGRITY SELECTIVE` datalinks.

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


Reading files
-------------

### read_text( file_path [ , position [ , length ] ] ) → text 
Read local file contents as text. 

Returns text.

If the file is linked with `READ ACCESS DB` access is first checked with `dl_authorize()`.
This implements access with filename-embedded read tokens as per SQL standard.
A user can alternatively have SELECT privilege on the directory to read the file.

### read_text( datalink [ , position [ , length ] ] ) → text
Read datalink contents as text. 

Returns text.

### read_lines( file_path [ , position ] ) → table (i,o,line)
Read local file contents as lines of text.

Returns set of lines with line numbers and file offset.

### read_lines( datalink [ , position ] ) → table (i,o,line)
Read datalink contents as lines of text. Currently works only for local file datalinks.

Returns set of lines with line numbers and file offset.


New file creation
------------------

### write_text( file_path , content text ) → integer
Write local file contents as text. File must not exist.

Returns number of bytes written.

User must have CREATE privilege on the directory.

### write_text( datalink , content text ) → datalink
Write datalink contents as text. New version of file is created.

Returns new datalink, which can be used for update of a datalink column.


Compatibility functions
-----------------------

### fileexists( datalink ) → boolean
Check if file exists.

### getlength( datalink ) → bigint
Return file size in bytes.

### instr( datalink , text ) → integer
Search for a string in text file, returns offset where found.

### substr( datalink [ , position [ , length ] ] ) → text
Return substring of length from a file starting with offset.

[Datalink manual](README.md)
