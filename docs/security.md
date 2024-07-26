[Datalink manual](README.md)

Security
========

Database roles
--------------


Directory privileges
--------------------

Exploded permissions for directories are in updatable view `datalink.access`. 
Database administrator can INSERT/UPDATE/DELETE individual privileges here.

Currently supported directory privileges:
- `SELECT` - read files
- `CREATE` - create new files
- `DELETE` - delete files
- `REFERENCES` - reference files (not implemented)

Granting a privilege:

    mydb=# insert into datalink.access values ('/var/www/datalink/','create',user);
    INSERT 0 1


[Datalink manual](README.md)
