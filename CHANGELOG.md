Version 0.17
------------
- fixes to dlurlcomplete

Version 0.16
------------
- datalink is now a real type (based on jsonb), not a domain
- use varchar's typmod in/out functions
- use atttypmod as LCO ; this  makes it work with pg_dump
- mark RI triggers as internal to remove them from pg_dump
- added cast from datalink to url

Version 0.15
------------
- pg_datalinker improvements: logging to file
- pg_datalinker improvements: maybe change file owner to relowner when read_access=DB
- rename: dl_fsprefix to dl_prfx
- error message improvements

Version 0.14
------------
- renames: datalink.column_options is now just datalink.columns
- better error reporting when integrity checking datalinks with curl_get()
- prevent updates of datalinks with write_access BLOCKED
- forbid UPDATE on columns where write_access = BLOCKED, set to ADMIN to make them updatable
- implemented write_access = TOKEN, meaning ADMIN REQUIRING TOKEN FOR UPDATE
- made DLURLCOMPLETE and others work on urls in addition to just datalinks
- added tables datalink.dl_linked_files and datalink.sample_datalinks to pg_dump backup
- convert relative to absolute URLs: use `dlvalue(url,dlvalue(base))`
- use `uri_set` part `src` to help turn relative urls into absolute
- `dlvalue` now creates comment only datalinks

Version 0.13
------------
- added list of volumes in /etc/postgresql-common/pg_datalinker.prefix
- added datalink.dl_fsprefix foreign table to this for use inside postgres
- added datalink.is_valid_prefix() function to check for valid volumes
- file_link() now throws an error if path doesn't have a valid volume prefix
- improved datalinker, also reads volumes from /etc/postgresql-common/pg_datalinker.prefix
- datalinker prefixes can be managed with `pg_datalinker ( init, list, add, del )` command
- datalinker can now revert old files from backups when assigning datalinks with tokens
- datalinker can now unlink+link in one operation
- trim trailing / on directory names for FS datalinks for better file name uniqueness
- dlnewcopy() now stores old token in link
- dlpreviouscopy() looks for this old token first
- store curl_head response code in datalink

Version 0.12
------------
- renames: domain datalink.dl_file_path is now just datalink.file_path
- improved checks on domain datalink.file_path
- file_path domain used in args to file functions
- added datalink.dl_lco(regclass,name) function
- got rid of dl_attlco table, lco now stored in dl_lco fdw option for column
- now uses attnum instead of attname in dl_linked_files
- alter table rename column works now
- changed dl_write_access 'ADMIN TOKEN' option to 'TOKEN', meaning ADMIN REQUIRING TOKEN FOR UPDATE
- renames: dl_linked_files.regclass is now attrelid for easier join with pg_attribute
- dlvalue(null) returns null
- autodetect link type in dlvalue()
- enable use of any string as link type. These are returned by dllinktype().
- automatic file path to url encoding

Version 0.11
------------
- use of [pguri](https://github.com/petere/pguri) extension for better url handling

Version 0.7
-----------
- column datalink.column_options.reglass replaced with 'table_name' of type text
- dlurlpath() now includes token when one is present in datalink

Version 0.5
-----------
- renames: dl_link_control_options -> link_control_options, dl_chattr() -> modlco(), dl_column_options -> dl_attlco
- skip changing link control options in datalink.modlco() when options not actually changed
- removed dl_triggers view and renamed dl_sql_advice() -> dl_trigger_advice()
- improved url validity checking with uri_get()
- improved uri_get() function
- dlpreviouscopy() now looks for token embedded in url
- dlpreviouscopy() works for text arguments
- better error reporting, per SQL spec with SQLSTATE
- new tests in url.sql
- bugfixes

Version 0.4
-----------
- added updatable view datalink.column_options to set link options with UPDATE
- added simple datalinker, but you have to run it manually
- reduced verbosity
- dl_column_options and dl_chattr now use regclass instead of (schema_name,table_name)
- changed ld_lco encoding to base 10 so that the options now display nicely as decimal digits in psql
- bugfixes

Version 0.3
-----------
- renames: dl_lco -> dl_link_control_options, dl_options -> dl_lco, dl_optionsdef -> dl_column_options
- better error reporting, per SQL spec with SQLSTATE
- added dl_link_control_options table with valid options
- added implicit casts for control options
- added uri_get() and uri_set() plperlu functions for power uri handling
- added SQL/MED standard functions DLURLSERVER() and DLURLSCHEME()
- added SQL/MED standard functions DLURLPATH() and DLURLPATHONLY()
- added function DLLINKTYPE(). Returns 'FS' for local files, 'URL' otherwise.
- implemented some rudimentary linking for INTEGRITY ALL. Links are kept in table datalink.dl_linked_files.
- event trigger for DROP TABLE now unlinks linked files
- event trigger for DROP COLUMN now unlinks linked files
- trigger for TRUNCATE now unlinks linked files
- removed dependancy on extension uuid-ossp

Version 0.2
-----------
- datalink type moved to pg_catalog
- internally, datalink is now domain over jsonb
- the head parameter to curl_get actually works now

Version 0.1
-----------
- initial github version
- moved SQL/MED standard functions such as dlvalue() to pg_catalog
- removed curl_head() function. use curl_get()
