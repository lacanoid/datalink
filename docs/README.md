Datalink manual
===============

Use Cases
---------

Datalinks are useful, where data are kept in files, together with metadata in SQL tables.
This can provide SQL query capabilities for files within SQL.

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

There are a number of reasons one might want to keep some data in files insted of storing it in a database.

- some files are very large and actual contents are not really needed in a database
- one wants to keep the original files
- access to files from outside the database
- files are very heavily used in all sort of web servers
- avoid overloading the database with file contents
- file content can often be streamed directly to the client

Some disciplines, which usually handle external files together with SQL data:

- World Wide Web publishing, where part of the website is often served as files
- Entertainment industry, where production assests are kept in multimedia files
- CAD/CAM, where models and schematics are kept in files
- Administration, where files are used to keep document scans
- Medical, where X-ray and other scans are kept in files

Architecture
------------
