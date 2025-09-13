[Datalink manual](README.md)

Security
========

Database roles
--------------

Database superuser have more privileges than normal users. They can call some functions such as `datalink.curl_get()`.
Also, they bypass some permission checks done for normal users.

Normal users can read existing files if they have `SELECT` privilege on directory or the datalink is linked with `READ ACCESS DB` option.

Normal users can create new files if they have `CREATE` privilege on directory.

All users, even superusers require `DELETE` privilege on appropriate directory to be able to delete files with `ON UNLINK DELETE` option.

Directory privileges
--------------------

Exploded permissions for directories are in updatable view `datalink.access`. 
Database administrator can INSERT/UPDATE/DELETE individual privileges here.

Currently supported directory privileges:
- `SELECT` - read files
- `CREATE` - create new files
- `DELETE` - delete files, this permission is required for *owner* of the table containing the ON UNLINK DELETE datalink column.
- `REFERENCES` - reference files (not implemented yet)

Granting a `DELETE` privilege to current user:

    mydb=# insert into datalink.access values ('/var/www/datalink/','delete',user);
    INSERT 0 1


[Datalink manual](README.md)
