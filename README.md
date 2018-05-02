Datalink extension for PostgreSQL
=================================

This attempts to implements some of the SQL/MED datalink functionality on PostgreSQL.
It is very much a prototype.

Installation
------------

You will need to install libwww-curl-perl first, as it is used by the extension.

To build and install this module:

    make
    make install
    make install installcheck

or selecting a specific PostgreSQL installation:

    make PG_CONFIG=/some/where/bin/pg_config
    make PG_CONFIG=/some/where/bin/pg_config install

And finally inside the database:

    CREATE EXTENSION datalink;

This of requires superuser privileges.

Using
-----

To be written. In the meantime, see tests for examples.


