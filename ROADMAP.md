Issues
======
- "create table as" doesn't seem to install triggers
- renaming of datalink columns

Wanted
=======
- Transactional File IO functions + file spaces
- init.d / systemd scripts for datalinker
- Native postgres URL type + functions
- Native postgres interface to curl

Todo
====
- dlurlpath() and dlurlcomplete() must include token
- replace link with one with different token
- optimize triggers (do not run them if mco=0)
- remove dl_link_control from dl_link_control_options (it is implied by dl_integrity)
- update trigger on dl_columns to call datalink.modlco()
- dl_ref and dl_unref redundant?
- link state handling: unlink -> linked, error -> ?
- file path sanity checking (handle ..)
- url sanity checking (handle ..)
- token decoding in dlvalue
- better URL syntax checking
- maybe loose Curl and check for files only
- URL canonization
- dlvalue better error handling
- make this work for non-superusers
- permissions
