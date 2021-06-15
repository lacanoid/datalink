Issues
======
- ✔︎ ALTER TABLE RENAME of datalink columns

Wanted
=======
✔︎ volumes
✔︎ replace link with one with different token
✔︎ Native postgres URL type + functions
- init.d / systemd scripts for datalinker
- Transactional File IO functions + file spaces / bfile like functionality
- Native postgres interface to curl
- some sort of file to url mapping. dlurl* functions could use these.
- Files on remote servers. Perhaps foreign servers + dblink

Todo
====
✔︎ CLI tool for datalinker admin
✔︎ much better error handling in datalinker
✔︎ dlvalue(null) -> null, dlvalue('') -> null
✔︎ file path sanity checking (handle or forbid ..)
✔︎ url sanity checking (handle ..)
✔︎ better URL syntax checking
✔︎ block files only on write_access=blocked
✔︎ URL canonization
✔︎ dlvalue autodetect link type
✔︎ use any string as link type (URL or FS)
✔︎ handle write_access = any ['BLOCKED','ADMIN','TOKEN']
- dlurlpath() must include token
- dlurlcomplete() must include token
- make dlvalue work for comment-only links
- revert files only when recovery=YES
- optimize table triggers (do not install them if mco=0)
- remove dl_link_control from dl_link_control_options (it is implied by dl_integrity)
- update trigger on dl_columns to call datalink.modlco()
- dl_ref and dl_unref redundant?
- better link state handling: unlink -> linked, error -> ?
- token decoding in dlvalue (in dlpreviouscopy and dlnewcopy)
- allow backups for read_access=fs LCO
- pg_extension_config_dump magic
- maybe: loose Curl and check for files only with stat
- dlvalue better error handling
- make this work for non-superusers
- ?implicit cast datalink -> url
- way to convert relative to absolute links: dlvalue(relative_link text, base_link datalink)
- set linked file owner to table owner
- permissions
