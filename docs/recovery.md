Recovery
--------

When `recovery` is `NO` then point-in-time recovery is not provided,
This option does not require datalinker.

when `recovery` is `YES` then point-in-time recovery is provided by the datalinker.

Backup and recovery uses token value as a backup identifier:

Let `base_file` be a corresponding file path for a datalink, 
such as one returned by `DLURLPATHONLY()`,
for example `/var/www/datalink.test3.txt`.

Let `backup_file` be a corresponding file path for a datalink including token, 
such as one returned by `DLURLPATH()`.
for example `/var/www/datalink.test3.txt#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33`.

The backup/restore works as follows:

1. If `base_file` exists and `backup_file` doesn't, then `base_file` is *copied* to `backup_file` using `cp -a`, file is *backed up*.

This way, one can create a new backup copy simply by saying:

    mydb=# UPDATE my_table SET link=DLNEWCOPY(link);

Each time a new token is assigned (and stored) a backup is created corresponding to that token:

    % cp -a /var/www/datalink.test3.txt /var/www/datalink.test3.txt#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33

2. If `base_file` doesn't exists and `backup_file` does, then `backup_file` is *linked* to `base_file` using `ln`, file is *restored*.

This way, one can restore old file version by assigning a datalink which inludes appropriate token:

    mydb=# INSERT INTO my_table (link) VALUES (DLVALUE('/var/www/datalink.test3.txt#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33'));

This will make file version `ae3cc23d-7a87-419a-b2f8-e6dc9d682d33` also available under a path without a token, `/dir1/dir2/file.ext`,
by performing, effectively restoring it:

    % ln /dir1/dir2/file.ext#ae3cc23d-7a87-419a-b2f8-e6dc9d682d33 /dir1/dir2/file.ext

Note that this is true link, not a symbolic one.

3. If both files exist, then `base_file` is first deleted and then `backup_file` is linked.

4. If neither file exists, then it is error. This is checked for in advance in `datalink.file_link()` function.

On unlink
---------

When `on_unlink` is `NONE` then no action is taken.
This option does not require datalinker.

When `on_unlink` is `RESTORE` then original file permissions are restored.

when `on_unlink` is `DELETE` then then file is deleted by the datalinker.

Files created for recovery are not deleted.


