[Datalink manual](README.md)

Datalink File Manager
=====================

Datalink File Manager (dlfs) component. Also known as *the datalinker*.
A process, external to PostgreSQL, which manages file permissions, backup, restore, replacement and deletion of files.

It consists of two parts:
- `dlfs` command for system administrators to configure and monitor the file manager
- [`pg_datalinker`](pg_datalinker.md) daemon, which is an actual file manager program which runs in the background


dlfs
-----

PostgreSQL datalink file manager control program

    # dlfs 

        show                 - show version and system configuration
        bind [dbname] [port] - bind file manager to a database
        unbind               - unbind file manager from a database

        list                 - list all registered file systems (directories)
        add <directory>      - register a file system (directory)
        del <directory>      - unregister a file system (directory)

        dirs                 - show directories
        usage                - show directory usage

        start                - starts the file manager
        stop                 - stop the file manager
        restart              - restart file manager
        status               - show file manager status
        ps                   - show the file manager processes running on the system
        log                  - monitor file manager log

Show version and system configuration
    
    # dlfs show
               server_version           | datname  | user | port | cluster_name 
    ------------------------------------+----------+------+------+--------------
     15.10 (Ubuntu 15.10-1.pgdg24.04+1) | postgres | root | 5432 | 15/main
    (1 row)

     extname  | extowner | extversion | columns | files | dirs 
    ----------+----------+------------+---------+-------+------
     datalink | root     | 0.24       |       3 |     0 |    7
    (1 row)

     pid  | cpid |  version  |         start         |         modify          | links | unlinks | errs 
    ------+------+-----------+-----------------------+-------------------------+-------+---------+------
     3215 | 3213 | 0.24.1012 | 1 day 08:55:11.893332 | 40 days 19:50:36.246282 |     3 |       4 |    0
    (1 row)

[Datalink manual](README.md)
