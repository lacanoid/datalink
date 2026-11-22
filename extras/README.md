A few extras
============

write_lines
-----------
Incremental file write function in the form of `datalink.write_lines(file_path,text)` SQL aggregate.
You can use this to stream query results directly to a file.

html_tidy
---------
Provides `html_tidy` functions to convert HTML pages to valid XML.
Uses perl's HTML::Tidy.

pg_databases
------------
Views:
- `datalink.pg_clusters` - as reported by `pg_clusters` unix command
- `datalink.pg_databases` - all online databases on the above pg_clusters
- `datalink.pg_roles` - all roles on the above pg_clusters

devices
-------
Provides view `datalink.devices` which show combined information reported by unix `df` and `mount` commands.
One can use this to find device size and available space.
