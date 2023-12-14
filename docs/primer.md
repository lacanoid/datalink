Here are some examples on how to use datalink

Creating datalink values
------------------------

You can create datalink values from text URLs by using `dlvalue()` function.

    mydb=# select dlvalue('http://www.github.io/');
                  dlvalue              
    ----------------------------------
     {"a": "http://www.github.io/"}
    (1 row)

One can think of datalinks as 'bookmarks' to internet resources.

Note that datalinks are internally represented as JSONB values, but should generally be considered as opaque values.

URLs are checked for syntax and wrong ones throw errors:

    mydb=# select dlvalue('foo bar');
    ERROR:  invalid input syntax for type uri at or near " bar"

URLs are normalized before they are converted to datalinks, so things like . and .. are resolved.

    mydb=# select dlvalue('http://www.github.io/a/b/c/d/../../e');
                    dlvalue                
    ---------------------------------------
     {"a": "http://www.github.io/a/b/e"}
    (1 row)

You can also use `dlvalue()` with absolute paths for file links. 
Weird characters in pathnames are properly URI encoded.

    mydb=# select dlvalue('/var/www/datalink/index.html');
                        dlvalue                     
    ------------------------------------------------
     {"a": "file:///var/www/datalink/index.html"}
    (1 row)

    mydb=# select dlvalue('/var/www/datalink/index?.html','FS');
                        dlvalue                     
    ------------------------------------------------
     {"a": "file:///var/www/datalink/index%3F.html"}
    (1 row)

    mydb=# select dlvalue('file:///var/www/datalink/index.html');
                        dlvalue                     
    ------------------------------------------------
     {"a": "file:///var/www/datalink/index.html"}
    (1 row)

Full form of function `dlvalue()` has a few more optional arguments:

- `DLVALUE(address [ ,link_type [ ,comment ] ] ) → datalink` (for INSERT)

`address`   - data address in text format, typically URL or a file path

`link_type` - either 'URL' or 'FS' (or 'FILE'). If ommitted or NULL, it is automatically determined from `address`

`comment`   - optional datalink text comment

Note that it is possible to create comment-only datalinks:

    mudb=# select dlvalue(null,null,'Hello');
          dlvalue      
    -------------------
     {"c": "Hello"}
    (1 row)


You can also use form `dlvalue(relative_address,dlvalue(base_address))` to convert relative to absolute URLs

    mydb=# select dlvalue('robots.txt',dlvalue('http://www.ljudmila.org/index.html'));
                    dlvalue                    
    -----------------------------------------------
     {"a": "http://www.ljudmila.org/robots.txt"}
    (1 row)


More
----
- [Functions](functions.md)
- [Referential integrity](integrity.md)
- [Access control](access.md)
- [Point in time recovery](recovery.md)
- [Configuration](configuration.md)




