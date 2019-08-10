Version 0.3alpha
----------------
- rename: dl_lco -> dl_link_control_options, dl_options -> dl_lco, dl_optionsdef -> dl_options
- added dl_link_control_options table with valid options
- added casts for control options
- added uri_get() and uri_set() plperlu functions for power uri handling
- added SQL/MED standard functions DLURLSERVER() and DLURLSCHEME()

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
