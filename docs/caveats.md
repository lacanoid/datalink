[Datalink manual](README.md)

Caveats
=======

## SQL compliance

This extension deviates from the SQL standard in following:

* No URL syntax checking for NO LINK CONTROL datalinks, one can add constraint with is_valid() function
* INTEGRITY SELECTIVE works somewhat differently, just checks if file exists and also works for web URLs
* DLURLSERVER() returns lowercase instead of uppercase
* SQL syntax for specifying link control options not supported, use type modifiers instead


[Datalink manual](README.md)
