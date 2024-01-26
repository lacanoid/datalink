Use Cases
=========

Datalinks are useful, where data are kept in files, together with metadata in SQL tables.
This can provide SQL query capabilities for files within SQL.

There are a number of reasons one might want to keep some data in files:
- some files are very large and actual contents are not really needed in a database
- one wants to keep the original files
- access to files from outside the database
- files are very heavily used in all sort of web servers
- avoid overloading database with file data
- file content can be streamed directly to the client

Some disciplines, which usually handle external files together with SQL data:

- World Wide Web publishing applications, where part of the website is often served as files
- Entertainment industry applications, where production assests are kept in multimedia files
- CAD/CAM applications, where models and schematics are kept in files
- Administration applications, where files are used to keep document scans
- Medical applications, where X-ray and other scans are kept in files
