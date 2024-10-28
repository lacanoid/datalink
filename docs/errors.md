[Datalink manual](README.md)

Errors
======

Curl
----

Functions `datalink.curl_get()` and `datalink.curl_save()` can return many errors in the `rc` field.

For Curl internal errors see [libcurl error codes](https://curl.se/libcurl/c/libcurl-errors.html).
For HTTP Errors see [List of HTTP status codes](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes).

Datalink warnings
-----------------

### DATALINK WARNING - external file possibly already linked

You are trying to link a file which although not linked now 
it seems to might have been linked previously 
but not properly unlinked thereafter.

### DATALINK WARNING - datalinker recommended

You are trying to perform an operation which really needs [datalinker](dlfm.md)
to completely complete.

### DATALINK WARNING - external file not linked

You are trying to use `datalink.has_updated(datalink)` on a datalink 
which is currently not linked. Datalink needs to be linked with
INTEGRITY ALL and WRITE ACCESS FS options which stores file timestamp
for this function to make sense.

### DATALINK WARNING - dblink extension recommended

Datalink exceptions
-------------------

### HW000 DATALINK EXCEPTION

General exception for when others won't do.

### HW001 DATALINK EXCEPTION - external file not linked

### HW002 DATALINK EXCEPTION - external file already linked

You are trying to link a file which has already been linked from another table.

### HW003 DATALINK EXCEPTION - referenced file does not exist

You are trying to link a file which does not exist.

### HW004 DATALINK EXCEPTION - invalid write token

### HW005 DATALINK EXCEPTION - invalid datalink construction

You are trying to INSERT a datalink constructed with
`dlpreviouscopy()` or `dlnewcopy()`. 
This is not allowed by the SQL standard.

### HW006 DATALINK EXCEPTION - invalid write permission for update

You are trying to update a datalink column with WRITE ACCESS BLOCKED option.

### HW007 DATALINK EXCEPTION - referenced file not valid

You are trying to change a datalink URL in a `dlnewcopy()` or `dlpreviouscopy()`.
This is not allowed by the SQL standard.

You are trying to link a file which is not in one of the allowed directories in `datalink.directory`.

You are trying to link a file which is neither a file nor a directory.

You are trying to link a file but file information (stat) could not be obtained.

You are trying to modify `datalink.directory` but `dirname` does not begin with a valid prefix from `datalink.dl_prfx`.

### DATALINK EXCEPTION - datalinker required

You are trying to perform an operation which really needs [datalinker](dlfm.md)
to completely complete.

### DATALINK EXCEPTION - cannot open file for reading

### DATALINK EXCEPTION - cannot open file for writing

### DATALINK EXCEPTION - file exists

You are using `datalink.write()` or `datalink.write_text()` 
but the file you are trying to create already exists.

### DATALINK EXCEPTION - failed to copy resource

You are using `dlreplacecontent()` but the operation failed. 
This can also occur if the source does not exist or cannot be read. (HW303)

### DATALINK EXCEPTION - SELECT permission denied on directory for role

### DATALINK EXCEPTION - CREATE permission denied on directory

### DATALINK EXCEPTION - DELETE permission denied on directory

### DATALINK EXCEPTION - directory does not exist

You are using `dlvalue(address, dirname)` function 
but directory `dirname` does not exist. (HW105)

You are are trying to modify `datalink.access` 
but `dirpath` does not contain a valid directory name. (HW103)

### DATALINK EXCEPTION - dl_file_new() failed

### DATALINK EXCEPTION - dblink extension required for files on foreign servers

### DATALINK EXCEPTION - foreign server does not exist

### DATALINK EXCEPTION - Filename is NULL

### DATALINK EXCEPTION - Foreign servers not supported in curl_save

### DATALINK EXCEPTION - waiting for datalinker


[Datalink manual](README.md)


