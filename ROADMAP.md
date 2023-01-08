Wanted
======
- ✔︎ volumes
- ✔︎ replace link with one with different token
- ✔︎ Native postgres URL type + functions
- ✔︎ way to convert relative to absolute links: dlvalue(relative_link text, base_link datalink)
- ✔︎ systemd scripts for datalinker
- ✔︎ install pg_wrapper for pg_datalinker
- install init.d scripts 
- Transactional File IO functions + file directories / bfile like functionality
- For constructor form dlvalue(basename,dirname) could be used, bfilename like
- some sort of file to url mapping. dlurl* functions could use these.
- Files on remote servers. Perhaps foreign servers + dblink
- get rid of plperlu, needs native postgres interface to curl_get, file_stat and uri_set
- some sort of permissions as to what gets to get/put where
- make it possible to change LCO with datalink values present
- make datalinks work with arrays

Issues
======
- ✔︎ Issues with encoding 'foo#bar' vs 'foo%23bar'. add tests.
- further pg_restore checks ; what happens to stuff in pg_linked_files?
- fordbid setting of lco<>0 for non superusers 

Todo
====
- ✔︎ CLI tool for datalinker admin
- ✔︎ much better error handling in datalinker
- ✔︎ dlvalue(null) -> null, dlvalue('') -> null
- ✔︎ file path sanity checking (handle or forbid ..)
- ✔︎ url sanity checking (handle ..)
- ✔︎ better URL syntax checking
- ✔︎ block files only on write_access=blocked
- ✔︎ URL canonization
- ✔︎ dlvalue autodetect link type
- ✔︎ use any string as link type (URL or FS)
- ✔︎ handle write_access = any ['BLOCKED','ADMIN','TOKEN']
- ✔︎ dlurlpath() must include token
- ✔︎ make dlvalue work for comment-only links
- ✔︎ set linked file owner to table owner
- ✔︎ make this work better with pg_dump
- ✔︎ dlurlcomplete() must include token
- ✔︎ update trigger on dl_columns to call datalink.modlco()
- more compact datalink storage (use 1 letter keys)
- throw errors if datalinker is not running when it should
- create explicit datalink.exists function
- skip curl for integrity='ALL' and check for files only with file_stat
- handle // urls and paths better
- datalinker: use config file
- datalinker: revert files only when recovery=YES
- datalinker: better path checking, have definitive functions
- datalinker: optimise verbosity
- datalinker: better configurator
- optimize table triggers (do not install them if mco=0)
- better link state handling: unlink -> linked, error -> ?
- token decoding in dlvalue (in dlpreviouscopy and dlnewcopy)
- dlvalue better error handling
- make this work for non-superusers
- check permissions
- datalink.file_stat() execute permissions

Maybe
=====
- remove link_control from link_control_options (it is implied by dl_integrity)
- allow backups for read_access=fs LCO

