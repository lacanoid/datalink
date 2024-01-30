[Datalink manual](README.md)

Datalink File Manager
=====================

Datalink File Manager (DLFM) component. Also known as *the datalinker*.
A process, external to PostgreSQL, which manages file persmissions, backup, restore, replacement and deletion of files.

It needs to run as UNIX superuser `root` because it needs to.

It consists of two parts:
- `dlfm` command for administrators to configure and monitor the file manager
- `pg_datalinker` command, which is an actual file manager program which runs in the background

Responsibilities
----------------

* Protect files from renaming or deletion (write_access=blocked,admin or token)
  
  This is done by setting the *immutable* flag on the file with `chattr +i` command.
  This prevents file from being renamed or modified, even by root.
  Datalinker itself must run as root to change file attributes.
  
* Make backups of files (recovery=yes)

  *Base file* is designated by path, for example `/dir1/dir2/file.ext`.
  *Backup file* is base file with appended token, such as `/dir1/dir2/file.ext#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33`.
  If backup file does not exist, it is created by creating a copy of the base file.

* Restore files from backups (recovery=yes)



* Make files owned by database (read_access=db)
* Restore file permissions (on_unlink=restore)
* Delete files no longer referenced (on_unlink=delete)

[Datalink manual](README.md)
