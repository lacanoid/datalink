[Datalink manual](README.md)

Transactional semantics
=======================

Postgres and datalinker
-----------------------

[Datalinker](dlfm.md) sees only transactions already commited in postgres. 
Datalink will attempt to discover errors and raise exceptions early.

Once the transaction is commited in postgres, the datalinker will attemp to 
modify the files accordingly. This is usually very quick, but not instantaneous.

Use procedure `datalink.commit()` to wait for datalinker to finish work.

    mydb=> call datalink.commit()
    CALL
 

Transactions and files
----------------------

Writing files with `write_text()` function supports transactional operation. 

If transaction which created a file is aborted, the datalinker will delete the file.

To transactionally update the file content, one must first store a corresponding
datalink in a column with `WRITE ACCESS ADMIN` or `WRITE ACCESS TOKEN`:

    mydb=# create table l (link datalink(372));
    NOTICE:  DATALINK DDL:TRIGGER on l
    CREATE TABLE
    
    mydb=# insert into l values (dlvalue(datalink.write_text('/var/www/datalink/hello.txt',fortune())));
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    INSERT 0 1

Updating works by writing content into new file(s). When the transaction is commited,
the datalinker will replace old files with new ones.

    mydb=# update l set link = datalink.write_text(link,fortune());
    NOTICE:  DATALINK UNLINK:/var/www/datalink/hello.txt
    NOTICE:  DATALINK LINK:/var/www/datalink/hello.txt
    UPDATE 1


[Datalink manual](README.md)
