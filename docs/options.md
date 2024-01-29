Link Control Options
====================

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

### LCO=xx0 NO LINK CONTROL

Only store datalinks.

Pro: Faster than other because of no trigger

### LCO=xx1 INTEGRITY SELECTIVE

Check if file exists.

Pro: Provides better referential integrity because referenced files have to actually exist.

Con: Files can still mysteriously disappear later.

Pro: Works for web as well as local files

### LCO=xx2 INTEGRITY ALL

Linked files are tracked in table `datalink.dl_linked_files`

Linked files are unique, each file can only be linked once.

Files can still be modified based of the file system permissions.

Pro: Does not modify files in any way.

Con: Only for local files.

### LCO=x1x READ ACCESS BLOCKED

Files are made immutable, so that they cannot be changed, renamed nor deleted, not even by the UNIX superuser.

Pro: Provides better referential integrity because files don't suddenly disappear while referenced from a database.

### LCO=x5x READ ACCESS DB

File is made to be "owned by the database", access control to file contents is to be controlled by the database environment.

File owner is changed to `postgresql`, used by PostgreSQL server process.

File group is changed to `www-data`, used by Apache server and `dlcat` command.

Read permissions on the file are given for said user and group. This makes the file readable by postgres server and apache, dlcat... 
Other permissions are removed, so the normal users can'r read the file anymore.

Note that this requires at least READ ACCESS BLOCKED option, so file will not be writable anyway.

Pro: Access file contents from the database environment

### LCO=x6x WRITE ACCESS TOKEN

Modify file contents from the database environment. Write write token must be present.

This requires access to the (previous) datalink value to be able to update it.

Note that this requires at least READ ACCESS DB option.

Pro: Provides transactional write access for files

Con: Potentionally destructive for files

### LCO=x7x WRITE ACCESS ADMIN

Modify file contents from the database environment. Write token is not required.

This is somewhat less strict version of WRITE ACCESS TOKEN, which allow updating a datalink to any value.

Note that this requires at least READ ACCESS DB option.

Pro: Provides transactional write access for files

Con: Potentionally destructive for files

### LCO=1xx,3xx RECOVERY YES

Provides point-in-time recovery of file contents.

Con: More space usage. It might be good to make use of *copy-on-write* feature of some filesystems, but I don't know
which ones support it and how to turn it on. It should be always on by default, anyway.

### LCO=2xx,3xx ON UNLINK DELETE

Delete the file from the filesystem after it is unlinked.

Note that this requires at least READ ACCESS DB (and thus also at least WRITE ACCESS BLOCKED) option.

This requires `DELETE` directory privilege in `datalink.access` for current user, even if superuser

Pro: Provides better referential integrity (like ON DELETE CASCADE)

Pro: Automatic cleanup of file no longer needed

Con: Potentionally destructive for files


