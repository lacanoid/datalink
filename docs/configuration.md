Configuration Parameters
========================

A lot of things must be configured right for everything to work.

SQL extension
-------------

### prefixes
A list of directories where linked files are allowed.
Normally found in `/etc/postgresql-common/pg_datalinker.prefix`.
These are set by the system administrator (root).

### directories
Updatable view `datalink.directories` is a set directories, where datalinks are to be located. 
Several additional options can be set, such as directory short name, permissions and url mapping.
These are set by the Postgres superuser.

### access privileges
Exploded permissions for directories are in updatable view `datalink.access`.


file manager
------------

### datalink database
Database used by pg_datalinker, containing linked files table.

### prefixes
A list of directories where linked files are allowed.
Normally found in `/etc/postgresql-common/pg_datalinker.prefix`.

### options


file filter
-----------

### datalink database
Database used for file authorization, containing linked files and insight tables.

File filter uses `datalink.dl_authorize()` function to check for access privileges.
