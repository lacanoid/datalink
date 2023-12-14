Configuration Parameters
========================

A lot of things must be configured right for everything to work.

Only one active datalink database and one active datalink file manager process on one host should be used.

### datalink database
Datalink database to be used, containing the datalink extension.
This should be configured in `/etc/postgresql-common/pg_service.conf` as a service `datalinker` with
specified `port` and `dbname` parameters. As ident authentitation is used, appropriate database users should be created.

### datalink database users
Database superuser `root` is needed to install `datalink` extension in the datalink database and run `pg_datalinker`.
Database user `www-data` is needed for apache to connect to the datalink database.

SQL extension
-------------

### prefixes
A list of directories where linked files are allowed.
Normally found in `/etc/postgresql-common/pg_datalinker.prefix`.
These are set by the system administrator (root).

### directories
Updatable view `datalink.directories` is a set directories, where datalinks are to be located. 
Several additional options can be set, such as directory short name, permissions and url mapping.
These are set by the database adnimistrator.

### directory access privileges
Exploded permissions for directories are in updatable view `datalink.access`. 
Database administrator can INSERT/UPDATE/DELETE individual privileges here.

Currently supported directory privileges:
- `SELECT` - read files
- `CREATE` - create new files
- `DELETE` - delete files

file manager
------------

### datalink database
This should be configured in `/etc/postgresql-common/pg_service.conf` as a service `datalinker`.

### prefixes
A list of directories where linked files are allowed.
Normally found in `/etc/postgresql-common/pg_datalinker.prefix`.

### options


file filter
-----------

### datalink database
This should be configured in `/etc/postgresql-common/pg_service.conf` as a service `datalinker`.
Database used for file authorization, containing linked files and insight tables.

File filter uses `datalink.dl_authorize()` function to check for access privileges.
