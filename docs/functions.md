Additional functions
====================
These are all in `datalink` schema.

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




