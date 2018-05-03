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

This extension lives mostly in `datalink` schema.
SQL/MED standard compliant functions are installed in `pg_catalog` schema, 
so they are accessible regardless of the search_path.

DATALINK type:

A special type `datalink.datalink` is provided. 
It behaves like SQL/MED DATALINK type.
When creating table columns of this type, 
datalink triggers are automatically installed on the table.

    create table sample_datalinks (
    	id serial,
    	url text,
    	link datalink.datalink
    );
    
    insert into sample_datalinks (link)
            values (dlvalue('http://www.debian.org');
            
DATALINK functions:

Constructors for values of type datalink:

- `DLVALUE(url) → datalink` (for INSERT)
- `DLNEWCOPY(url,tokenp) → datalink` (for UPDATE)
- `DLPREVIOUSCOPY(url,tokenp) → datalink` (for UPDATE)

Functions for extracting information from datalink type:

- `DLURLCOMPLETE(datalink) → url`
- `DLURLCOMPLETEONLY(datalink) → url`
- `DLCOMMENT(datalink) → text`

See also
--------
- tests contain some examples
- https://wiki.postgresql.org/wiki/DATALINK
- SQL/MED standard


