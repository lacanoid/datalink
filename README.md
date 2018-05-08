Datalink extension for PostgreSQL
=================================

This attempts to implement some of the SQL/MED datalink functionality on PostgreSQL.
It is very much a prototype and meant for playing around to see if this can be made useful.
Also to see how much of the standard can be implemented in high-level postgres, 
without having to resort to C.

Implemented with a mix of plpgsql and plperlu. Perl is used for interfacing with curl.
 
Currently, it implements the following:
- SQL/MED DATALINK type
- SQL/MED DATALINK constructors DLVALUE, DLPREVIOUSCOPY and DLNEWCOPY
- SQL/MED functions DLURLCOMPLETE, DLURLCOMPLETEONLY
- Event and other triggers to make all of this 'just work'
- `dl_ref()` and `dl_unref()` functions through which datalink referencing is routed
- link control options (LCO) functions
- token generator
- plperlu interface to curl via WWW::Curl
- DLCOMMENT function
- LCO: NO LINK CONTROL
- LCO: FILE LINK CONTROL - check if file exists with curl head

Missing:
- SQL/MED functions DLURLSCHEME, DLURLSERVER
- SQL/MED functions DLURLPATH, DLURLPATHONLY
- SQL/MED functions DLURLCOMPLETEWRITE, DLURLPATHWRITE
- SQL/MED functions DLREPLACECONTENT
- DLLINKTYPE function
- LCO: READ ACCESS DB
- LCO: WRITE ACCESS BLOCKED
- LCO: WRITE ACCESS ADMIN
- LCO: WRITE ACCESS ADMIN TOKEN
- LCO: ON UNLINK RESTORE
- LCO: ON UNLINK DELETE
- LCO: RECOVERY YES
- datalinker processes
- URL type + functions
- Transactional File IO functions + spaces
- native postgres interface to curl

Installation
------------

You will need to have 
[WWW::Curl](http://search.cpan.org/~szbalint/WWW-Curl-4.17/lib/WWW/Curl.pm#WWW::Curl::Easy) 
Perl package installed, as it is used by the extension.
On Debian, you can install `libwww-curl-perl` package.

To build and install this module:

    make
    make install
    make install installcheck

or selecting a specific PostgreSQL installation:

    make PG_CONFIG=/some/where/bin/pg_config
    make PG_CONFIG=/some/where/bin/pg_config install

And finally inside the database:

    CREATE EXTENSION datalink;

This requires superuser privileges.

Using
-----

This extension lives mostly in `datalink` schema.
SQL/MED standard compliant functions are installed in `pg_catalog` schema, 
so they are accessible regardless of the search_path.

Event trigger `datalink_event_trigger` is installed. 
It takes care of adding datalink triggers to tables, which contain datalink columns.
Datalink triggers take care of referencing and dereferencing datalinks 
as values are assigned to datalink columns.

DATALINK type:

A special type DATALINK is provided. 
It behaves like SQL/MED DATALINK type.
When creating table columns of this type, 
datalink triggers are automatically installed on the table.

    create table sample_datalinks (
    	id serial,
    	url text,
    	link datalink
    );
    
    insert into sample_datalinks (link)
            values (dlvalue('http://www.debian.org'));
            
    select dlurlcomplete(link)
      from sample_datalinks;
            
DATALINK functions:

Constructors for values of type datalink:

- `DLVALUE(url[,link_type][,comment]) → datalink` (for INSERT)
- `DLNEWCOPY(datalink,tokenp) → datalink` (for UPDATE)
- `DLPREVIOUSCOPY(datalink,tokenp) → datalink` (for UPDATE)

Functions for extracting information from datalink type:

- `DLURLCOMPLETE(datalink) → url`
- `DLURLCOMPLETEONLY(datalink) → url`
- `DLCOMMENT(datalink) → text`

See also
--------
- tests contain some examples
- https://wiki.postgresql.org/wiki/DATALINK
- SQL/MED standard


