Issues
======
- ✔︎ ALTER TABLE RENAME of datalink columns

Wanted
=======
- ✔︎ volumes
- ✔︎ replace link with one with different token
- ✔︎ Native postgres URL type + functions
- ✔︎ way to convert relative to absolute links: dlvalue(relative_link text, base_link datalink)
- init.d / systemd scripts for datalinker
- Transactional File IO functions + file directories / bfile like functionality
- For constructor form dlvalue(basename,dirname) could be used
- some sort of file to url mapping. dlurl* functions could use these.
- Files on remote servers. Perhaps foreign servers + dblink
- get rid of plperlu, needs native postgres interface to curl_get, file_stat and uri_set
- install pg_wrapper for pg_datalinker

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
- skip curl for integrity='ALL' and check for files only with stat
- handle // urls
- further pg_restore check ; what happens to stuff in pg_linked_files?
- fordbid setting of lco<>0 for non superusers 
- datalinker: revert files only when recovery=YES
- datalinker: better path checking, have definitive functions
- optimize table triggers (do not install them if mco=0)
- better link state handling: unlink -> linked, error -> ?
- token decoding in dlvalue (in dlpreviouscopy and dlnewcopy)
- dlvalue better error handling
- make this work for non-superusers
- check permissions
- datalink.file_stat() execute permissions
- remove link_control from link_control_options (it is implied by dl_integrity)
- allow backups for read_access=fs LCO
