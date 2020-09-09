Version 0.7
-----------
- column datalink.column_options.reglass replaced with 'table_name' of type text
- DLURLPATH now includes token when present

Version 0.5
-----------
- renames: dl_link_control_options -> link_control_options, dl_chattr() -> modlco(), dl_column_options -> dl_attlco
- skip changing link control options in datalink.modlco() when options not actually changed
- removed dl_triggers view and renamed dl_sql_advice() -> dl_trigger_advice()
- improved url validity checking with uri_get()
- improved uri_get() function
- dlpreviouscopy() now looks for token in embedded in url
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
