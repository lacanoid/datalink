Responsibilities
----------------
* Protect files from renaming or deletion (write_access=blocked,admin or token)
* Make backups of files (recovery=yes)
* Restore files from backups (recovery=yes)
* Make files owned by database (read_access=db)
* Restore file permissions (on_unlink=restore)
* Delete files no longer referenced (on_unlink=delete)

Datalinker runs a loop checking entries in `datalink.dl_linked_files` table.
Here it sees the results of transactions already commited in postgres.
Files in state `LINK` go into state `LINKED` when successfully linked otherwise `ERROR`.

