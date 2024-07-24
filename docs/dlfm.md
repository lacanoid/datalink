[Datalink manual](README.md)

Datalink File Manager
=====================

Datalink File Manager (DLFM) component. Also known as *the datalinker*.
A process, external to PostgreSQL, which manages file permissions, backup, restore, replacement and deletion of files.

It consists of two parts:
- `dlfm` command for system administrators to configure and monitor the file manager
- [`pg_datalinker`](pg_datalinker.md) daemon, which is an actual file manager program which runs in the background


dlfm
-----

PostgreSQL datalink file manager control program

    # dlfm 

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


[Datalink manual](README.md)
