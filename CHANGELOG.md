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
- datalink type move to pg_catalog
- internally, datalink is now domain over jsonb
- the head parameter to curl_get actually works now

Version 0.1
-----------
- initial github version
- moved SQL/MED standard functions such as dlvalue() to pg_catalog
- removed curl_head() function. use curl_get()
