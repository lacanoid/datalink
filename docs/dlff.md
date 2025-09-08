[Datalink manual](README.md)

Datalink File Filter
====================

Datalink File Filter (DLFF) component authorizes access to files linked with `READ ACCESS DB` link control option.

For such datalinks, SQL functions `DLURLCOMPLETE()` and `DLURLPATH()` will produce addresses with embeded *read access token*.
This token is in turn used by the SQL function `datalink.dl_authorize()` to authorize access to the file. 
This function is then used by the various front-ends.

Firstly, let us make some datalinks:

    mydb=# create table t ( link datalink(52) );
    NOTICE:  DATALINK DDL:TRIGGER on t
    CREATE TABLE

    mydb=# insert into t values (dlvalue('/var/www/datalink/test1.txt'));
    NOTICE:  DATALINK LINK:/var/www/datalink/test1.txt
    INSERT 0 1


Apache Module
-------------

Provided is Apache 2 mod_perl module `datalink.conf`, which is installed into `/etc/apache2/sites-available`.

Enable it with:

    % a2ensite datalink

This can be used with links provided by `DLURLCOMPLETE()` SQL function. 

Be sure to also set `dirurl` in `datalink.directory` to enable file-to-URL mapping to get HTTP instead of FILE URLs.

    mydb=# update datalink.directory set dirurl='http://localhost/datalink/' where dirpath='/var/www/datalink/';

You will probably want to eventually set `dirurl` to a fully qualified URL for your server.

    mydb=# select dlurlcomplete(link) from t;
                                    dlurlcomplete                                 
    ------------------------------------------------------------------------------
    http://localhost/datalink/738a74c2-4126-4350-947b-e9f0c0735411;test1.txt
    (1 row)


dlcat
-----

This is similar to `cat` UNIX shell command, but it works with filenames with embedded read tokens.
It will print the contents of the file(s) to standard output. 
It is a SUID/SGID command (with www-data:www-data), which accesses the files and database pretending to
be a web server.

This can be used with filenames provided by `DLURLPATH()` SQL function. 

    my_db=# select dlurlpath(link) from t;
                                dlurlpath                             
    ------------------------------------------------------------------
    /var/www/datalink/738a74c2-4126-4350-947b-e9f0c0735411;test1.txt
    (1 row)

    $ dlcat '/var/www/datalink/738a74c2-4126-4350-947b-e9f0c0735411;test1.txt'


SQL file functions
------------------

Functions `datalink.read_text` and `datalink.read_lines` provide support for read access tokens.

    my_db=# select datalink.read_text('/var/www/datalink/738a74c2-4126-4350-947b-e9f0c0735411;test1.txt');

It will probably be easier still to use them with datalinks directly:

    my_db=# select datalink.read_text(link) from t;


Direct file system access (libc)
--------------------------------

File filter is currently not implemented for direct file system access (using libc). 

Perhaps FUSE filesystem might make sense here. 

[Datalink manual](README.md)
