[Datalink manual](README.md)

Datalink type
==============

You can create datalink values from text URLs by using [`dlvalue()`](functions.md#user-content-sql-datalink-constructors) function.

    mydb=> select dlvalue('http://www.github.io/');
                  dlvalue              
    ----------------------------------
     {"a": "http://www.github.io/"}
    (1 row)

One can think of datalinks as 'bookmarks' to internet resources.

Note that datalinks are internally represented as JSONB values, but should generally be considered as opaque values.

You will normally want to store datalinks in tables:

    mydb=> create table t ( link datalink );
    CREATE TABLE
    mydb=> insert into t values (dlvalue('http://www.github.com'));
    INSERT 0 1
    mydb=> select dlurlcomplete(link) from t;
        dlurlcomplete     
    -----------------------
    http://www.github.com
    (1 row)

One can see datalink columns for the whole database in view `datalink.columns`.

    mydb=> table datalink.columns ;
     table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
     t          | link        | NO           | NONE      | FS          | FS           | NO       | NONE
    (1 row)

Superusers will see all datalink columns whereas normal users will see only columns for owned tables.

The above example does not specify any control options for a datalink column. This will not install
any triggers on the table, resulting in a much faster performance, but potentionally allowing for
invalid URLs to creep in. Note that `dlvalue()` constructor function does check for valid URLs. 


Link Control Options
--------------------

Datalink *link control options* are specified per datalink column 
and apply to all datalinks stored in that column. They specify datalink behaviour.

Valid link control option combinations (per SQL standard) 
are listed in the `datalink.link_control_options` table:

    mydb=# table datalink.link_control_options ;
     lco | link_control | integrity | read_access | write_access | recovery | on_unlink 
    -----+--------------+-----------+-------------+--------------+----------+-----------
       0 | NO           | NONE      | FS          | FS           | NO       | NONE
       1 | FILE         | SELECTIVE | FS          | FS           | NO       | NONE
       2 | FILE         | ALL       | FS          | FS           | NO       | NONE
      12 | FILE         | ALL       | FS          | BLOCKED      | NO       | RESTORE
      52 | FILE         | ALL       | DB          | BLOCKED      | NO       | RESTORE
      62 | FILE         | ALL       | DB          | TOKEN        | NO       | RESTORE
      72 | FILE         | ALL       | DB          | ADMIN        | NO       | RESTORE
     112 | FILE         | ALL       | FS          | BLOCKED      | YES      | RESTORE
     152 | FILE         | ALL       | DB          | BLOCKED      | YES      | RESTORE
     162 | FILE         | ALL       | DB          | TOKEN        | YES      | RESTORE
     172 | FILE         | ALL       | DB          | ADMIN        | YES      | RESTORE
     252 | FILE         | ALL       | DB          | BLOCKED      | NO       | DELETE
     262 | FILE         | ALL       | DB          | TOKEN        | NO       | DELETE
     272 | FILE         | ALL       | DB          | ADMIN        | NO       | DELETE
     352 | FILE         | ALL       | DB          | BLOCKED      | YES      | DELETE
     362 | FILE         | ALL       | DB          | TOKEN        | YES      | DELETE
     372 | FILE         | ALL       | DB          | ADMIN        | YES      | DELETE
    (17 rows)

Value `lco` from the table can be used in `CREATE TABLE` statements with datalinks
to set the control options at table creation time. One can specify control options as a type
modifier for the `datalink` type:

    mydb=# create table t (link datalink(52));
    NOTICE:  DATALINK DDL:TRIGGER on t
    CREATE TABLE
    mydb=# select * from datalink.columns where table_name='t';
    table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
    t          | link        | FILE         | ALL       | DB          | BLOCKED      | NO       | RESTORE

When link control is `FILE` (type modifier is distinct from 0) then datalink triggers are added to the table. 
These take care of managing datalinks as they are stored.

Once the datalink columns are created, one can change control options by updating `datalink.columns` with
the SQL UPDATE statement. Changing the options has some limitiations when datalink values are already present in the table.

    mydb=# update datalink.columns set write_access='ADMIN' where table_name='t';
    UPDATE 1
    mydb=# \d t
                        Table "public.t"
    Column |     Type      | Collation | Nullable | Default 
    --------+---------------+-----------+----------+---------
    link   | datalink(162) |           |          | 

    mydb=# select * from datalink.columns where table_name='t';
    table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
    t          | link        | FILE         | ALL       | DB          | ADMIN        | NO       | RESTORE


Note that updating `datalink.columns` has changed the type modifier on the column.

Option description and use cases
--------------------------------

### LCO=0 NO LINK CONTROL

Only store datalinks.

Pro: Much faster than other settings because there are no triggers to run

Con: URL syntax is not checked when assigning, but it is checked by `dlvalue()`.

One can add check for valid URL by using constraints at the cost of slight performance penalty:

    mydb=> alter table my_table add check (datalink.is_valid(link));


### LCO=xx1 INTEGRITY SELECTIVE

Check if file exists.

Pro: Provides better referential [integrity](integrity.md) because referenced files have to actually exist.

Con: Files can still mysteriously disappear later.

Pro: Works for web as well as local files

Con: Differs from SQL standard (standard requires 'linking' and rename+delete protection if available, we only check if file exists)

### LCO=xx2 INTEGRITY ALL

Linked files are tracked in table `datalink.dl_linked_files`

Linked files are unique, each file can only be linked once.

Files must be located in predefined directories from `datalink.directory`.

Files can still be modified based of the file system permissions.

Pro: Does not modify files in any way.

Con: Only for local files.

Con: Differs from SQL standard (standard requires rename+delete (but not write) protection)

### LCO=x1x WRITE ACCESS BLOCKED

Files are made immutable, so that they cannot be changed, renamed nor deleted, not even by the UNIX superuser.

Pro: Provides better referential integrity because files don't suddenly disappear while referenced from a database.

### LCO=x5x READ ACCESS DB

File is made to be "owned by the database", access control to file contents is to be controlled by the database environment.

File owner is changed to `postgresql`. This makes file readable PostgreSQL server process and thus database superuser.

File group is changed to `www-data`. This makes file readable by Apache server and `dlcat` command.

Read permissions on the file are set for owner and group. other permissions are removed, so that normal users can'r read the file anymore.

Note that this requires at least READ ACCESS BLOCKED option, so file will not be writable anyway.

Pro: Access file contents from the database environment

### LCO=x6x WRITE ACCESS TOKEN

Modify file contents from the database environment. Matching write token must be present.

This requires access to the (previous) datalink value to be able to update it.

Note that this requires at least READ ACCESS DB option.

Pro: Provides transactional write access for files

Con: Potentionally destructive to files

### LCO=x7x WRITE ACCESS ADMIN

Modify file contents from the database environment. Write token is not required.

This is somewhat less strict version of WRITE ACCESS TOKEN, which allow updating a datalink to any value.

Note that this requires at least READ ACCESS DB option.

Pro: Provides transactional write access for files

Con: Potentionally destructive to files

### LCO=1xx,3xx RECOVERY YES

Provides point-in-time recovery of file contents. See [recovery](recovery.md)

Con: More space usage. 

Con: Slower

### LCO=2xx,3xx ON UNLINK DELETE

Delete the file from the filesystem after it is unlinked.

Note that this requires at least READ ACCESS DB (and thus also at least WRITE ACCESS BLOCKED) option.

This requires `DELETE` directory privilege in `datalink.access` for current user, even if superuser

Pro: Provides better referential integrity (like ON DELETE CASCADE)

Pro: Automatic cleanup of file no longer needed

Con: Potentionally destructive to files


[Datalink manual](README.md)
