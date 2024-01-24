Link Control Options
====================

Datalink *link control options* are specified per datalink column 
and apply to all datalinks stored in that column.

Possible link control option combinations are listed in `datalink.link_control_options` table.

    my_db=# table datalink.link_control_options;
    lco | link_control | integrity | read_access | write_access | recovery | on_unlink 
    -----+--------------+-----------+-------------+--------------+----------+-----------
    0   | NO           | NONE      | FS          | FS           | NO       | NONE
    1   | FILE         | SELECTIVE | FS          | FS           | NO       | NONE
    2   | FILE         | ALL       | FS          | FS           | NO       | NONE
    22  | FILE         | ALL       | FS          | BLOCKED      | NO       | RESTORE
    32  | FILE         | ALL       | FS          | BLOCKED      | YES      | RESTORE
    122 | FILE         | ALL       | DB          | BLOCKED      | NO       | RESTORE
    132 | FILE         | ALL       | DB          | BLOCKED      | YES      | RESTORE
    142 | FILE         | ALL       | DB          | TOKEN        | NO       | RESTORE
    152 | FILE         | ALL       | DB          | TOKEN        | YES      | RESTORE
    162 | FILE         | ALL       | DB          | ADMIN        | NO       | RESTORE
    172 | FILE         | ALL       | DB          | ADMIN        | YES      | RESTORE
    322 | FILE         | ALL       | DB          | BLOCKED      | NO       | DELETE
    332 | FILE         | ALL       | DB          | BLOCKED      | YES      | DELETE
    342 | FILE         | ALL       | DB          | TOKEN        | NO       | DELETE
    352 | FILE         | ALL       | DB          | TOKEN        | YES      | DELETE
    362 | FILE         | ALL       | DB          | ADMIN        | NO       | DELETE
    372 | FILE         | ALL       | DB          | ADMIN        | YES      | DELETE
    (17 rows)

Note that `lco` value from the table can be used in `CREATE TABLE` statements with datalinks
to set the control options at table creation time:

    my_db=# create table t (link datalink(122));
    my_db=# select * from datalink.columns where table_name='t';
    table_name | column_name | link_control | integrity | read_access | write_access | recovery | on_unlink 
    ------------+-------------+--------------+-----------+-------------+--------------+----------+-----------
    t          | link        | FILE         | ALL       | DB          | BLOCKED      | NO       | RESTORE
    (1 row)

