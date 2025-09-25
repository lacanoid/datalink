[Datalink manual](README.md)

Transactional semantics
=======================

Note that synchronizing things between transactional environment like SQL 
and external non-transactional environment poses certrain challenges. 
Care must be taken when accessing external resources such as web sites from
within the transactional environment of SQL, as such resources normally do not 
behave transactionaly and do not provide rollback capabilities.

The datalink system itself is essentially a two stage commit process, where changes 
are first recorded in the database and then applied by the [datalinker](dlfs.md) process.

When files are beeing written transactionally, a new copy of the file is first written
by postgres. The datalinker then replaces old files with new ones. This is somewhat
analogous to the way MVCC rows are created in postgres itself. This applies to functions
`datalink.write()`, `datalink.write_text()` and `dlreplacecontent()`.


Postgres and datalinker
-----------------------

[Datalinker](pg_datalinker.md) sees only transactions already commited in postgres. 
Datalink extension will attempt to discover errors early and raise exceptions,
before updates reach the datalinker.

Once the transaction is commited in postgres, the datalinker will attempt to 
modify the files accordingly. This is usually very quick, but not instantaneous.

Use procedure `datalink.commit()` to wait for datalinker to finish work and become idle.

    mydb=> call datalink.commit()
    CALL
 
Note that this has to be called outside a transaction.

Transactions and files
----------------------

Writing files with `write_text(file_path, persistent integer)` function allows for writing
new files. For this, the user must have CREATE privilege on appropriate directory.

If parameter `persistent` > 1 this is a persistent file, otherwise it is a temporary file.
Temporary files are deleted when the transaction commits.

If transaction which creates a file is aborted, the datalinker will delete the file.

Writing files with `write_text(datalink, persistent integer)` function also supports transactional 
updates of file contents.

To transactionally update the file content, one must first store a corresponding
datalink in a column with `WRITE ACCESS ADMIN` or `WRITE ACCESS TOKEN`:

    mydb=# create table l (link datalink(372));
    NOTICE:  DATALINK DDL:TRIGGER on l
    CREATE TABLE
    
    mydb=# insert into l values (datalink.write_text(dlvalue('hello.txt','www'),'New content'));
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    INSERT 0 1

Alternatively, one can use `dlreplacecontent()` function to copy content from the web:

    mydb=# insert into l values (dlreplacecontent(dlvalue('robots.txt','www'),'http://www.google.com/robots.txt'));
    NOTICE:  DATALINK LINK:/var/www/datalink/robots.txt
    INSERT 0 1


Updating works by writing content into new file(s) referenced by datalinks:

    mydb=# update l set link = datalink.write_text(link,'New content');
    NOTICE:  DATALINK UNLINK:/var/www/datalink/hello.txt
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    UPDATE 1

Again, one can use `dlreplacecontent()` function to fetch new content from the web:

    mydb=# update l set link = dlreplacecontent(link,'http://www.google.com/robots.txt');
    NOTICE:  DATALINK UNLINK:/var/www/datalink/hello.txt
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    UPDATE 1

When the transaction commits, the datalinker will replace old files with new ones.

Thus the contents of the file have been updated to the value 'New content'.

[Datalink manual](README.md)
