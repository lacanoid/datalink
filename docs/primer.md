Here are some examples on how to use datalink

Creating datalink values
------------------------

You can create datalink values from URLs by using `dlvalue()` function.

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
    CONTEXT:  PL/pgSQL function dlvalue(text,datalink.dl_linktype,text) line 15 at assignment

URLs are normalized before they are converted to datalinks.

    mydb=# select dlvalue('http://www.github.io/a/b/c/d/../../e');
                    dlvalue                
    ---------------------------------------
     {"url": "http://www.github.io/a/b/e"}
    (1 row)

Use `dlurlcompleteonly()` function to convert a datalink back to URL.

    mydb=# select dlurlcompleteonly(dlvalue('http://www.github.io/a/b/c/d/../../e'));
          dlurlcompleteonly      
    ----------------------------
     http://www.github.io/a/b/e
    (1 row)

You can also use dlvalue() with absolute paths for file links.

    mydb=# select dlvalue('/var/www/datalink/index.html');
                        dlvalue                     
    ------------------------------------------------
     {"url": "file:///var/www/datalink/index.html"}
    (1 row)

Use `dlurlpathonly()` function to get file path from a datalink.

    mydb=# select dlurlpathonly(dlvalue('/var/www/datalink/index.html'));
             dlurlpathonly         
    ------------------------------
     /var/www/datalink/index.html
    (1 row)

