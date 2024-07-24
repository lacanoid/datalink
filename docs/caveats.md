[Datalink manual](README.md)

Caveats
=======

## SQL compliance

This extension differs from the SQL standard in following:

* SQL syntax for specifying link control options is not supported, use type modifiers and UPDATE datalink.columns instead
* No URL syntax checking for NO LINK CONTROL datalinks, one can add constraint with is_valid() function
* INTEGRITY SELECTIVE works somewhat differently, no linking, just checks if file exists and also works for web URLs
* DLURLSERVER() returns lowercase instead of uppercase server name
* linked files for INTEGRITY ALL and WRITE ACCESS FS are not protected from renaming or deletion, use WRITE ACCESS BLOCKED

[Datalink manual](README.md)
