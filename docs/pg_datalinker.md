[Datalink manual](README.md)

pg_datalinker
=============

Datalinker runs a loop checking entries in `datalink.dl_linked_files` table.
Here it sees the results of transactions already commited in postgres.

It then attempts to modify linked files accordingly.

It is not meant to be run directly, but rather managed with [`dlfm`](dlfm.md) command.

Responsibilities
----------------
* Protect files from renaming or deletion (write_access=blocked,admin or token)
  
  This is done by setting the *immutable* flag on the file with `chattr +i` command.
  This prevents file from being renamed or modified, even by root.
  Datalinker itself must run as root to change file attributes.
  
* Make backups of files (recovery=yes)

  *Base file* is designated by path, for example `/dir1/dir2/file.ext`.
  *Backup file* is base file with appended token, such as `/dir1/dir2/file.ext#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33`.
  If backup file does not exist, it is created by creating a copy of base file.

* Restore files from backups (recovery=yes)
* Make files owned by database (read_access=db)
* Restore file permissions (on_unlink=restore)
* Delete files no longer referenced (on_unlink=delete)

Datalinker connects to postgres service "datalinker", so make sure it is configured
in file `/etc/postgresql-common/pg_service.conf`.

Files in state `LINK` go into state `LINKED` when successfully linked otherwise they go into state `ERROR`.

Files in state `UNLINK` are unlinked and deleted from table `datalink.dl_linked_files`.
If `ON_UNLINK` is `DELETE` then the files are also deleted from filesystem.

Options
-------
$opt_O: if owner (of the table containing the datalink column) 
is equal to an existing OS user, it is set as the owner of the file thus making it readable to 
that user. This is meant to work with Postgres *ident* authetication on Debian 
linux and elsewhere, where database user is same as OS user.

[Datalink manual](README.md)


