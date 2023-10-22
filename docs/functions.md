Additional functions
====================
These are all in `datalink` schema.

curl_get(url, header_only)
--------------------------
Use CURL to fetch a URL from the World Wide Web.

read_text(file_path [,position [,length] ] )
--------------------------------------------
Read datalink contents as text. Returns text.

read_lines(file_path [,position] )
----------------------------------
Read datalink contents as lines of text.
Returns set of lines with line numbers and file offset.

uri_get(url, part)
------------------
Get a part of URI

uri_set(url, part, value)
------------------
Set a part of URI

fileexists(datalink)
--------------------
Check if file exists.

getlength(datalink)
-------------------
Return file size.

instr(datalink,text)
--------------------
Search for a string in file, returns offset where found.

substr(datalink [,position [,length] ] )
----------------------------------------









