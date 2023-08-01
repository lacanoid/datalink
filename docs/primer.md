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

Note that datalinks are internally represented as JSONB values, but should generally be considered opaque values.

URLs are checked for syntax and wrong ones throw errors.

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

- `DLVALUE(address[,link_type][,comment]) → datalink` (for INSERT)

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


Datalink functions
------------------

Most of these are overloaded to work on text as well as datalinks. If argument is passed as text, it is implicitly converted to datalink first.

Use `dlurlcomplete()` and `dlurlcompleteonly()` functions to convert datalinks back to URLs.

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

Use `dlcomment()` function to get datalink comment.

    mydb=# select dlcomment(dlvalue('https://user:password@www.gitgub.io:1234/foo/bar','URL','A comment...'));
      dlcomment 
    --------------
     A comment...
    (1 row)


Next: [Referential integrity](integrity.md)




