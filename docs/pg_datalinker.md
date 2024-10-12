[Datalink manual](README.md)

pg_datalinker
=============

Datalinker runs a loop checking entries in `datalink.dl_linked_files` table.
Here it sees the results of transactions already commited in postgres.

It then attempts to modify linked files accordingly.

It is not meant to be run directly, but rather managed with [`dlfm`](dlfm.md) command.

It needs to run as UNIX superuser `root` because it needs to.

Responsibilities
----------------
* Protect files from renaming or deletion (WRITE ACCESS BLOCKED OR TOKEN OR ADMIN)
  
  This is done by setting the *immutable* flag on the file with `chattr +i` command.
  This prevents file from being renamed or modified, even by root.
  Datalinker itself must run as root to change file attributes.
  
* Make backups of files (RECOVERY YES)

  *Base file* is designated by path, for example `/dir1/dir2/file.ext`.
  *Backup file* is base file with appended token, such as `/dir1/dir2/file.ext#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33`.
  If backup file does not exist, it is created by creating a copy of base file.

* Restore files from backups (RECOVERY YES)

* Replace files with new versions (WRITE ACCESS TOKEN OR ADMIN)

* Make files owned by database (READ ACCESS DB)

  File owner is set to user `postgres`, making a file effectively owned by the postgres server process.
  File group is set to `www-data`, making file readable to apache web server.
  File mode is set to 0440, making file unreadable by normal users.
  Previous protection is stored in `datalink.dl_linked_files` table.

* Restore file permissions (ON UNLINK RESTORE)

  File owner, group and mode are restored values previously stored in `datalink.dl_linked_files` table.

* Delete files no longer referenced (ON UNLINK DELETE)

* Purge files created from postgres

  This deletes files created by `datalink.write()` and such if the transaction was aborted or
  if the transaction was commited and file is temporary.

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


