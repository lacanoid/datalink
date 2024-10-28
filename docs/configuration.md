[Datalink manual](README.md)

Configuration Parameters
========================

A lot of things must be configured right for everything to work.

Only one active datalink database and one active datalink file manager process on one host should be used.

### datalink database
Datalink database to be used, containing the datalink extension.
This should be configured in `/etc/postgresql-common/pg_service.conf` as a service `pg_datalink` with
specified `port` and `dbname` parameters. As ident authentitation is used, appropriate database users should be created.

Datalink database can be configured by using `dlfm bind` and `dlfm unbind` shell commands.

### datalink database users
Database superuser `root` is needed to install `datalink` extension in the datalink database and run `pg_datalinker`.
Database user `www-data` is needed for apache to connect to the datalink database.

### prefixes
A list of directories where linked files are allowed.
Normally found in `/etc/postgresql-common/pg_datalinker.prefix`.
These are managed by the *system administrator* (root).

Prefixes can be viewed by using `dlfm list` shell command.

Prefixes can be managed by using `dlfm add` and `dlfm del` shell commands.

### directories
Updatable view `datalink.directories` is a set directories, 
where datalinks are to be located. 
They typically mirror (and are limited to) prefixes. 
They are managed by the *database administrator*.
Several additional options can be set, 
such as directory short name, permissions and url mapping.

Directories can be viewed by using `dlfm dirs` shell command.

### directory access privileges
Exploded permissions for directories are available
in updatable view `datalink.access`. 
Database administrator can INSERT/UPDATE/DELETE individual privileges here.

Currently supported directory privileges:
- `SELECT` - read files
- `CREATE` - create new files
- `DELETE` - delete files

### datalinker options

These specify details on how [datalinker](pg_datalinker.md) should work.

[Datalink manual](README.md)

