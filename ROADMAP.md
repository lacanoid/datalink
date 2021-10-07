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
- Native postgres interface to curl

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
- make this work better with pg_dump
- if integrity=all check for file only with datalink.file_stat() 
- make // urls default to https:
- dlurlcomplete() must include token
- revert files only when recovery=YES
- optimize table triggers (do not install them if mco=0)
- update trigger on dl_columns to call datalink.modlco()
- better link state handling: unlink -> linked, error -> ?
- token decoding in dlvalue (in dlpreviouscopy and dlnewcopy)
- skip curl for integrity='ALL' and check for files only with stat
- dlvalue better error handling
- make this work for non-superusers
- better datalinker path checking
- check permissions
- datalink.file_stat() execute permissions
- remove link_control from link_control_options (it is implied by dl_integrity)
- allow backups for read_access=fs LCO
