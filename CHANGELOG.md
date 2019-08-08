Version 0.3alpha
----------------
- rename: dl_lco -> dl_link_control_options, dl_options -> dl_lco

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
