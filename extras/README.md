A few extras
============

write_lines
-----------
Incremental file write function in the form of `datalink.write_lines(file_path,text)` SQL aggregate.
You can use this to stream query results directly to a file thus avoiding having to keep this in RAM.

    my_db=> insert into my_links (link)
            select dlvalue(datalink.write_lines('/var/www/datalink/events.txt',format))
            from (
              select format('%s',summary)
	        from atom.vevent_list_view
               order by dtstart desc
            ) a;

html_tidy
---------
Provides `html_tidy` functions to convert HTML pages to valid XML.
Uses perl's HTML::Tidy.

pg_databases
------------
Views:
- `datalink.pg_clusters` - as reported by `pg_lsclusters` unix command
- `datalink.pg_databases` - all online databases in the above pg_clusters
- `datalink.pg_roles` - all roles in the above pg_clusters

devices
-------
Provides view `datalink.devices` which show combined information reported by unix `df` and `mount` commands.
One can use this to find device size and available space.

curl_response_codes
-------------------
Uses datalink and html_tidy to get a list of CURL response codes from https://curl.se/libcurl/c/libcurl-errors.html 
then adds them to `datalink.http_response_codes`.
