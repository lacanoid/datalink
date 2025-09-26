[Datalink manual](README.md)

SQL Datalink constructors
-------------------------

### dlvalue

#### dlvalue( address text [ , link_type text [ , comment text ] ] ) → datalink

Make a datalink by specifying file `address`.

Address depends on `link_type`. Internally, address is always stored as URL.

For link type `URL`, address is specified as URL: 

    mydb=> select dlvalue('http://www.github.org','URL');
                dlvalue             
    --------------------------------
     {"a": "http://www.github.org"}
    (1 row)

Note that address must conform to legal URL syntax (e.g. no spaces, no unicode).

For link type `IRI`, address is specified as IRI where unicode characters are permitted: 

    select dlvalue('http://München.de/resumé.txt','IRI');
                      dlvalue                      
    ---------------------------------------------------
     {"a": "http://xn--mnchen-3ya.de/resum%C3%A9.txt"}
    (1 row)

For server names [Punycode encoding](https://en.wikipedia.org/wiki/Punycode) is used.


For link type `FS`, address is specified as absolute file path (beginning with /):

    mydb=> select dlvalue('/var/www/datalink/my file.txt','FS');
                         dlvalue                   
    -------------------------------------------------
     {"a": "file:/var/www/datalink/my%20file.txt"}
    (1 row)

Please observe that URLs are escaped, while file paths are not.

If link type is NULL or ommitted, then it is auto-detected from `address`:

    mydb=> select dlvalue('http://www.github.org');
                 dlvalue             
    --------------------------------
     {"a": "http://www.github.org"}
    (1 row)

    mydb=> select dlvalue('/var/www/datalink/my file.txt');
                         dlvalue                   
    -------------------------------------------------
     {"a": "file:/var/www/datalink/my%20file.txt"}
    (1 row)

When link type is equal to some `dirname` in table `datalink.directory` 
then `address` is taken to be relative to that directory:

    mydb=> select dlvalue('test1.txt','www');
                            dlvalue                         
    ---------------------------------------------------------
     {"a": "file:/var/www/datalink/test1.txt", "t": "www"}
    (1 row)

#### dlvalue( address text [ , base datalink [ , comment text ] ] ) → datalink

Make a datalink, relative to another datalink.

    mydb=> select dlvalue('style.css',dlvalue('http://www.github.org/index.html'));
                     dlvalue                  
    ------------------------------------------
     {"a": "http://www.github.org/style.css"}
    (1 row)

### versioning

#### dlnewcopy( datalink [ , has_token integer ] ) → datalink

Generate a new token value for a datalink. This is used for indicating that the file contents have changed.

If `has_token` > 0 then the previous token will also be stored in a datalink. This can be used for update
of `WRITE ACCESS TOKEN` columns.

Updating a `RECOVERY YES` datalink column with the new value of the datalink will also cause datalinker to 
create a new backup of file contents.

#### dlpreviouscopy( datalink [ , has_token integer ] ) → datalink

Return previous version of the datalink, if available. 

Updating a `RECOVERY YES` datalink column with the previous value of the datalink will cause datalinker to restore
previous version of file contents.

If `has_token` > 0 then the function will try to establish token value for a datalink in the following order:
1. previous token value stored in a datalink
2. token value stored in a datalink
3. look for token in datalink filename
4. generate a new token

### copying file contents

#### dlreplacecontent( target datalink, source datalink ) → datalink

This function will replace content of `target` datalink (a local file)
with the contents of `source` (can be on anywhere the web). 

Returns a a datalink value, which can be used in an INSERT or UPDATE of a datalink column.

Web page is first downloaded directly into a temporary local file from within
postgres function `datalink.curl_save()` with CURL GET request.

Updating and commiting a `WRITE ACCESS ADMIN` or `WRITE ACCESS TOKEN` datalink column 
will then cause datalinker to replace contents of a linked file with the downloaded file.

When the transaction concludes, temporary file is deleted.

    mydb=# insert into l values (dlreplacecontent('/var/www/datalink/robots.txt','http://www.google.com/robots.txt'));
    NOTICE:  DATALINK LINK:/var/www/datalink/robots.txt
    INSERT 0 1

    mydb=# update l set link = dlreplacecontent(link,'http://www.google.com/robots.txt');
    NOTICE:  DATALINK UNLINK:/var/www/datalink/robots.txt
    NOTICE:  DATALINK LINK:/var/www/datalink/robots.txt
    UPDATE 1



SQL Datalink scalar functions
-----------------------------

These are specified by the SQL/MED standard.

Most of these have been overloaded to work on text URLs as well as datalinks. If argument is passed as text, it is implicitly converted to datalink first.

#### dlurlcomplete( datalink [ , anonymous integer ] ) → text

Use `dlurlcomplete()` function to convert datalinks back to URLs. 

    mydb=> select dlurlcomplete(dlvalue('http://www.github.io/a/b/c/d/../../e'));
            dlurlcomplete      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    mydb=> select dlurlcomplete('http://www.github.io/a/b/c/d/../../e');
            dlurlcomplete      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

For READ ACCESS DB datalinks URL will contain read access token.
Tokens are generated when INTEGRITY ALL datalinks are stored in tables and are used to authorize read access to the file content.

    mydb=> create table t ( link datalink(52) ); 
    NOTICE:  DATALINK DDL:TRIGGER on t
    CREATE TABLE
    mydb=> insert into t values (dlvalue('/var/www/datalink/test1.txt')); 
    NOTICE:  DATALINK LINK:/var/www/datalink/test1.txt
    INSERT 0 1

    mydb=> select dlurlcomplete(link) from t;
                                  dlurlcomplete                              
    -------------------------------------------------------------------------
     file:/var/www/datalink/b6fd3d9b-45bb-400b-b2f5-fcd72c380434;test1.txt
    (1 row)

When parameter `anonymous` is nonzero, then generated read tokens will be unique and appropriate records will be inserted into `datalink.insight` table.
This can be used to avoid revealing stored tokens. Access can be revoked by deleting entries from `datalink.insight`.

#### dlurlcompleteonly( datalink ) → text

Use `dlurlcompleteonly()` function to convert datalinks back to URLs. URL never contains access token.
The function also omits any `fragment` part of the URL (stuff after #)

    mydb=> select dlurlcompleteonly(dlvalue('http://www.github.io/a/b/c/d/../../e'));
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    mydb=> select dlurlcompleteonly('http://www.github.io/a/b/c/d/../../e');
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

    mydb=> select dlurlcompleteonly(link) from t;
             dlurlcompleteonly          
    ------------------------------------
     file:/var/www/datalink/test1.txt
    (1 row)

#### dlurlpath( datalink [ , anonymous integer ] ) → text

Use `dlurlpath()` function to get file path from datalink. File path may contain access token.

    mydb=> select dlurlpath(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlpath 
    -----------
     /foo/bar
    (1 row)
    
    mydb=> select dlurlpath('https://user:password@www.gitgub.io:1234/foo/bar');
     dlurlpath 
    -----------
     /foo/bar
    (1 row)

    mydb=> select dlurlpath(link) from t;
                                dlurlpath                             
    ------------------------------------------------------------------
     /var/www/datalink/b6fd3d9b-45bb-400b-b2f5-fcd72c380434;test1.txt
    (1 row)

When parameter  `anonymous` is nonzero, then generated read tokens will be unique and 
appropriate records will be inserted into the `datalink.insight` table.
This can be used to avoid revealing stored tokens and keep evidence of accesses. 
Access can be revoked by deleting entries from `datalink.insight`.

#### dlurlpathonly( datalink ) → text

Use `dlurlpathonly()` function to get file path from datalink. File path never contains access token.

    mydb=> select dlurlpathonly(dlvalue('/var/www/datalink/index.html'));
             dlurlpathonly         
    ------------------------------
     /var/www/datalink/index.html
    (1 row)

    mydb=> select dlurlpathonly(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlpathonly 
    ---------------
     /foo/bar
    (1 row)

    mydb=> select dlurlpathonly(link) from t;
            dlurlpathonly        
    -----------------------------
     /var/www/datalink/test1.txt
    (1 row)

#### dlurlscheme( datalink ) → text

Use `dlurlscheme()` function to get uppercased URL scheme part of a datalink.

    mydb=> select dlurlscheme(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
     dlurlscheme 
    -------------
     HTTPS
    (1 row)

#### dlurlserver( datalink ) → text

Use `dlurlserver()` function to get lowercased URL server part of a datalink.
This does not include username and password if they are present in URL.

    mydb=> select dlurlserver(dlvalue('https://user:password@www.github.io:1234/foo/bar'));
      dlurlserver  
    ---------------
     www.github.io
    (1 row)

    mydb=> select dlurlserver('https://user:password@www.github.io:1234/foo/bar');
      dlurlserver  
    ---------------
     www.github.io
    (1 row)

#### dlcomment( datalink ) → text

Use `dlcomment()` function to get datalink comment.

    mydb=> select dlcomment(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar','URL','A comment...'));
      dlcomment 
    --------------
     A comment...
    (1 row)

This function is not in SQL standard, but is available in other implementations.

#### dllinktype( datalink ) → text

Use `dllinktype()` function to get datalink type, as specified or determined in `dlvalue()`.

    mydb=> select dllinktype(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar'));
    dllinktype 
    ------------
     URL
    (1 row)

    mydb=> select dllinktype(dlvalue('/var/www/datalink/test1.txt'));
    dllinktype 
    ------------
     FS
    (1 row)

    mydb=> select dllinktype(dlvalue('test1.txt','www'));
    dllinktype 
    ------------
    www
    (1 row)

This function is not in SQL standard, but is available in other implementations.


Additional functions
====================

These are not specified by the SQL standard, but are provided for the user's convenience.
Thay are all in the `datalink` schema.

Validation
----------

These are intended to be used with constraints.

#### is_valid( datalink ) → boolean

Indicates that a datalink URL is valid.

#### is_local( datalink ) → boolean

Indicates that a datalink references a local file.

#### is_http_success( datalink ) → boolean

Indicates that a HTTP request was successfully completed.

URI manipulation
----------------

#### uri_get( uri text, part ) → text

Get a part of URI, returns text.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.

#### uri_get( datalink , part ) → text

Get a part of a datalink's URI, returns text.
Part can be one of  `scheme`, `server`, `userinfo`, `host`, `path`, `basename`, `query`, `fragment`, `token`, `canonical` or `only`.

#### uri_set( uri text, part , value text ) → text

Set a part of URI to a value, returns new URI.
Part can be one of  `src`, `scheme`, `server`, `authority`, `path_query`, `userinfo`, `host`, `port`, `host_port`, `path`, `basename`, `query`, `fragment` or `token`.

Web access
----------

#### curl_get( url text [ , mode integer  ] ) → record

Use CURL to fetch content from the World Wide Web via GET request.

    mydb=# select * from datalink.curl_get('http://localhost/datalink/test1.txt');
                     url                 | ok | rc  | body  | error | elapsed  
    -------------------------------------+----+-----+-------+-------+----------
     http://localhost/datalink/test1.txt | t  | 200 | Hello+|       | 0.019225
                                         |    |     |       |       | 
    (1 row)


Parameter `mode` specifies what should be returned:

* **0 - headers only.** HEAD request is made instead of GET, returning only HTTP request headers.
This is used to check for the existence of `INTEGRITY SELECTIVE` datalinks.

* **1 - unicode text.** Returned body is assumed to contain unicode text. This is the default.

* **2 - binary.** Returned body will be bytea encoded. You will probably want to explicitly cast it bytea type.

When file: URLs refer to files on other servers, [PostgreSQL foreign servers](foreign_server.md) are used.

Only superuser can execute this function, execute permission for other users must be explicitly granted.


#### curl_save( local_file file_path, url text [ , persistent integer ] ) → record

Use CURL to fetch content from the World Wide Web via GET request and save it to a local file.

When parameter `persistent` is nonzero, then created file will be permanent, otherwise it will be temporary and deleted and the end of the transaction.

Only superuser can execute this function, execute permission for other users must be explicitly granted.


Reading files
-------------

#### read_text( file_path [ , position [ , length ] ] ) → text 
Read local file contents as text. 

Returns text.

If the file is linked with `READ ACCESS DB` access is first checked with `dl_authorize()`.
This implements access with filename-embedded read tokens as per SQL standard.
A user can alternatively have SELECT privilege on the directory to read the file.

#### read_text( datalink [ , position [ , length ] ] ) → text
Read datalink contents as text. Datalink can be anywhere on the web.

Returns text.

#### read( file_path [ , position [ , length ] ] ) → bytea 
Read local file contents as binary. 

Returns bytea.

If the file is linked with `READ ACCESS DB` access is first checked with `dl_authorize()`.
This implements access with filename-embedded read tokens as per SQL standard.
A user can alternatively have SELECT privilege on the directory to read the file.

#### read_lines( file_path [ , position ] ) → table (i,o,line)
Read local file contents as lines of text.

Returns set of lines with line numbers and file offset.

#### read_lines( datalink [ , position ] ) → table (i,o,line)
Read datalink contents as lines of text. Currently works only for local files.

Returns set of lines with line numbers and file offset.


New file creation
------------------

#### write_text( file_path , content text [ , persistent integer ] ) → text
Write local file contents as text. File must not exist. This is to prevent overwriting existing files.

Returns given file path. This can be passed as argument to DLVALUE() for use in INSERT statement.
    
    mydb=# insert into l values (dlvalue(datalink.write_text('/var/www/datalink/hello.txt','New content')));
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    INSERT 0 1

When parameter `persistent` is nonzero, then created file will be permanent, otherwise it will be temporary and deleted and the end of the transaction.

User must have CREATE privilege on the directory.

#### write_text( datalink , content text [ , persistent integer ] ) → datalink
Write datalink contents as text. New version of file is created and then old file is replaced by the datalinker when transaction is commited.

This is typically used in UPDATE statements.

    mydb=# update l set link = datalink.write_text(link,'New content');
    NOTICE:  DATALINK UNLINK:/var/www/datalink/hello.txt
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    UPDATE 1

When parameter `persistent` is nonzero, then created file will be permanent, otherwise it will be temporary and deleted and the end of the transaction.

Returns new datalink, which can be used for update of a datalink column.

#### write( file_path , content bytea [ , persistent integer ] ) → text
Write local file contents as binary. File must not exist. This is to prevent overwriting existing files.

Returns given file path. This can be passed as argument to DLVALUE() for use in INSERT statement.

When parameter `persistent` is nonzero, then created file will be permanent, otherwise it will be temporary and deleted and the end of the transaction.

User must have CREATE privilege on the directory.

#### write( datalink , content bytea [ , persistent integer ] ) → datalink
Write datalink contents as binary. New version of file is created and then old file is replaced by the datalinker when transaction is commited.

This is typically used in UPDATE statements.

When parameter `persistent` is nonzero, then created file will be permanent, otherwise it will be temporary and deleted and the end of the transaction.

Returns new datalink, which can be used for update of a datalink column.

File information functions
--------------------------

#### fileexists( datalink ) → integer
Check if file exists.

#### getlength( datalink ) → bigint
Return file size in bytes.

#### has_updated( datalink ) → integer
Returns whether linked file has changed since it was linked. This makes sense only for INTEGRITY ALL WRITE ACCESS FS datalinks.

(In)compatibility functions
---------------------------

These are in `pg_catalog` schema, so generally you don't need to specify a schema.

#### substr( datalink [ , position [ , length ] ] ) → text
Return substring of length from a file starting with offset.

#### length( datalink ) → bigint
Return file size in bytes. Same as `datalink.getlength()`, but less typing.

[Datalink manual](README.md)
