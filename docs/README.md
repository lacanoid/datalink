Datalink manual
===============

Use Cases
---------

Datalinks are useful, where data are kept in files, together with metadata in SQL tables.
This can provide SQL query capabilities for files within SQL.

There are a number of reasons one might want to keep some data in files insted of storing it in a database:

- some files are very large and actual contents are not really needed in a database
- one wants to keep the original data files
- access to files from outside the database
- files are very heavily used in all sort of web servers
- avoid overloading the database infrastructure with file contents
- file content can often be streamed directly to the client

Some disciplines, which usually handle external files together with SQL data:

- World Wide Web publishing, where parts of the website are often served as files
- Creative industries, where production assests are kept in multimedia files
- CAD/CAM, where models and schematics are kept in files
- Content delivery, where streaming assests are kept in files
- Administration, where files are used to keep PDF documents and such
- Medical, where X-ray and other scans are kept in files

DATALINK is special SQL type intended to store references to external files in the database.
Only references to external files are stored in the database, not the content of the files themselves.
Files are addressed with [Uniform Resource Locators (URLs)](https://en.wikipedia.org/wiki/URL).

The standard states: "The purpose of datalinks is to provide a mechanism to synchronize the 
integrity control, recovery, and access control of the files and the SQL-data associated with them. "

Datalinks as defined by SQL/MED should provide:

- [DATALINK SQL datatype](type.md)
- [SQL scalar functions operating on DATALINK type](functions.md)
- Transactional semantics
  - [Integrity](integrity.md)
    - [URL syntax validation](type.md)
    - [Checking if file exists](integrity.md)
    - [Protection of linked file against renaming or deletion](access.md)
    - [Automatic deletion of files no longer referenced from database](recovery.md)
  - [Access control](access.md)
    - [Read access control through database](access.md)
    - [Write access control through database](access.md)
  - [Point-in-time recovery of file contents](recovery.md)
- Access to files on different servers (for datalinks with `FILE` scheme)

This extension provides a number of additional features:
- [URL manipulation](functions.md#user-content-uri-manipulation)
- [File system to URL mapping](dlff.md)
- [Web access via CURL](functions.md#user-content-web-access)
- [File reading and writing](functions.md#user-content-reading-files)
- [Directory permissions system](configuration.md)
- [Compatibility functions](functions.md#user-content-compatibility-functions)

Architecture
------------

The datalink system is made of three main components:

- a PostgreSQL extension `datalink` to be used from SQL, providing DATALINK within SQL environment. The extension by itself does not perform any potentionally destructive file system changes, although it can create new files if allowed by file system permissions. 
- [datalink file manager](dlfm.md) (DLFM) deamon, [`pg_datalinker`](pg_datalinker.md), which handles all file manipulations. 
The extension can be used without a daemon, but this disables some of the functionality.
- [datalink file filter](dlff.md) (DLFF), which applies READ ACCESS DB policy to file accesses. 

