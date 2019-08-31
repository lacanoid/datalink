Issues
======
- trigger for users are broken
- create table as doesn't seem to install triggers
- bug in dl_class_adminable?
- renaming of datalink columns

Todo
====
- optimize triggers (do not run them if mco=0)
- remove dl_link_control from dl_link_control_options (it is implied by dl_integrity)
- update trigger on dl_columns to call dl_chattr()
- dl_ref and dl_unref redundant?
- link state handling: unlink -> linked, error -> ?
- file path sanity checking (handle ..)
- url sanity checking (handle ..)
- token decoding in dlvalue
- better URL syntax checking
- URL canonization
- dlvalue better error handling
- make this work for non-superusers
- permissions
