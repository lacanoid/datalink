Wanted
======
- ✔︎ prefixes, directories
- ✔︎ replace link with one with different token
- ✔︎ Native postgres URL type + functions
- ✔︎ way to convert relative to absolute links: dlvalue(relative_link text, base_link datalink)
- ✔︎ systemd scripts for datalinker
- ✔︎ install pg_wrapper for pg_datalinker
- install init.d scripts 
- ✔︎ Transactional File IO functions + file directories / bfile like fileio functionality
- ✔︎ For constructor form dlvalue(basename,dirname) could be used, bfilename like
- ✔︎ datalink.write_text() function to create new files
- some sort of permissions as to what and who gets to do where. probably postgres acls.
  - ✔︎ SELECT - read file contents
  - REFERENCES - link to files from database (WRITE ACCESS BLOCKED)
  - ✔︎ DELETE - delete files (ON UNLINK DELETE)
  - ✔︎ CREATE - create new files
- ✔︎ some sort of file to url mapping. dlurl* functions could use these.
- ✔︎ make `dlurlcomplete()` and `dlurlpath()` include read access tokens when read_access = 'DB'
- ✔︎ make read access tokens work with table datalink.insight ( ctime, read_token, link_token, state, role, pid, data  )
- ✔︎ SUID/SGID shell command `dlcat` to read contents from filenames with embedded read tokens, returned by `dlurlpath()`
- ✔︎ apache module to make it work with embedded read tokens, returned by `dlurlcomplete()`
- ✔︎ make `dlfm` command line tool for datalinker admin
- add suspend/unsuspend operations to datalinker for better dump/restore (suspend=stop datalinker and restore all original file permissions)
- make it possible to change LCO with datalink values present
- add copy file and move file operations
- ✔︎ Files on remote servers. Perhaps foreign servers + dblink
- ✔︎ make domains on datalinks work
- make datalinks work with arrays
- build simple webserver into pg_datalinker
- perhaps [FUSE](https://en.wikipedia.org/wiki/Filesystem_in_Userspace) could be useful for this? 
- get rid of plperlu, needs new implementations of functions curl_get, file_stat and uri_set
- perhaps [pg_curl](https://github.com/RekGRpth/pg_curl) could be helpful?
- better documentation (manual)
- better handling of already immutable files
- apache mod_perl directory autoconfigurator
- `curl_get(url,params json)` function which supplies query string from json
- add `curl_post` and `curl_put` functions
- add vacuum procedure for deleting temporary files (those not linked)
- add vacuum procedure for managing `datalink.insight`
- add `mtime` to `dl_linked_files` and a function to check if a datalink has changed

Issues
======
- ✔︎ Issues with encoding 'foo#bar' vs 'foo%23bar'. add tests.
- further pg_restore checks ; what happens to stuff in pg_linked_files?
- forbid setting of lco<>0 for non superusers 
- `create table as` / `select into` bug (data is loaded before triggers are run)
- domain on domain on datalink doesn't work

Todo
====
- ✔︎ CLI tool for datalinker admin
- ✔︎ much better error handling in datalinker
- ✔︎ dlvalue(null) → null, dlvalue('') → null
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
- ✔︎ optimize table triggers (do not install them if mco=0)
- ✔︎ throw warnings/errors if datalinker is not running when it should
- additional permission checks for delete, references
- consider WRITE ACCESS ADMIN/TOKEN and with respect to RECOVERY YES and file replace.
- skip curl for integrity='ALL' and check for files only with file_stat (file exists but is not readable by postgres)
- handle // urls and paths better
- datalinker: use config file
- datalinker: revert files only when recovery=YES
- datalinker: better path checking, have definitive functions
- datalinker: optimise verbosity
- datalinker: better configurator
- datalinker: don't die so easily
- datalinker: update owner+group in dl_linked_files.info only if not default
- function to wait for datalinker to finish
- better link state handling: unlink → linked, error → ?
- better file handling wrt. immutable state
- token decoding in dlvalue (now in dlpreviouscopy and dlnewcopy)
- dlvalue better error handling
- make this work for non-superusers
- datalink.dl_file_stat() execute permissions
- remove requirements to have `root` (pg_datalinker DB user) be a superuser, have a special non supersuser role for this
- comment and token diffusion in dlvalue()
- verify if ok: user (current role vs table owner) vs directory acls

Maybe
=====
- ✔︎ perl function to read text file sequentialy and return a set of (i int,o bigint,line text) 
- add DLVALUE(uri, ...)
- directory listing function, maybe called datalink.catalog()
- ✔︎ add datalink.uri_get(datalink,...)
- ✔︎ create explicit datalink.exists(datalink) function, or perhaps datalink.get_info(datalink)
- ✔︎ more compact datalink storage (use 1 letter json keys)
- remove link_control from link_control_options (it is implied by dl_integrity)
- allow backups for read_access=fs LCO
- more pluggable filename+token handling so we can support more common token;basename convention
- ✔︎ add timing info to curl_get()
- better punycode support in `dlvalue()`
- support for http ranges in `curl_get()` (and apache handler!)

BFile API
=========
✔︎ FUNCTION FILEEXISTS (file_loc IN BFILE) RETURN INTEGER;  

✔︎ PROCEDURE FILEGETNAME (file_loc IN BFILE, dir_alias OUT TEXT, filename OUT TEXT); 

PROCEDURE OPEN (file_loc IN OUT BFILE, open_mode IN INTEGER := file_readonly);

FUNCTION ISOPEN (file_loc IN BFILE) RETURN INTEGER;

PROCEDURE CLOSE (file_loc IN OUT BFILE); 

PROCEDURE FILECLOSEALL; 

✔︎ FUNCTION GETLENGTH (file_loc IN BFILE) RETURN INTEGER;

PROCEDURE READ (file_loc IN BFILE, amount IN OUT INTEGER, offset IN INTEGER, buffer OUT RAW);

✔︎ FUNCTION SUBSTR (file_loc IN BFILE, amount IN INTEGER := 32767, offset IN INTEGER := 1) RETURN RAW;

✔︎ FUNCTION INSTR (file_loc IN BFILE, pattern IN RAW, offset IN INTEGER := 1,nth IN INTEGER := 1) RETURN INTEGER;

PROCEDURE LOADFROMFILE(dest_lob IN OUT CLOB, src_file IN BFILE, amount IN INTEGER, dest_offset IN INTEGER := 1, src_offset IN INTEGER := 1);

FUNCTION COMPARE (lob_1 IN BFILE, lob_2 IN BFILE, amount IN INTEGER, offset_1 IN INTEGER := 1, offset_2 IN INTEGER := 1) RETURN INTEGER;
