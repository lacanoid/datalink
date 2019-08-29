Datalink extension for PostgreSQL
=================================

This attempts to implement some of the SQL/MED datalink functionality on PostgreSQL.
It is very much a prototype and meant for playing around to see if this can be made useful.
Also to see how much of the standard can be implemented in high-level postgres (and pgperlu :), 
without having to resort to C. It currently doesn't do anything very useful.

Implemented with a mix of plpgsql and plperlu. Perl is used for interfacing with curl and for uri handling.
 
Currently, it implements the following:
- SQL/MED DATALINK type
- SQL/MED DATALINK constructors DLVALUE, DLPREVIOUSCOPY and DLNEWCOPY
- SQL/MED functions DLURLCOMPLETE, DLURLCOMPLETEONLY
- SQL/MED functions DLURLSCHEME, DLURLSERVER
- SQL/MED functions DLURLPATH, DLURLPATHONLY
- DLLINKTYPE function
- DLCOMMENT function
- Event and other triggers to make all of this 'just work'
- Setting link control options with "UPDATE DATALINK.COLUMN_OPTIONS"
- token generator
- plperlu interface to curl via WWW::Curl
- URI handling functions `uri_get()` and `uri_set()`
- simple datalinker
- LCO: NO LINK CONTROL - only check for valid URLs
- LCO: FILE LINK CONTROL INTEGRITY SELECTIVE - check if file exists with CURL HEAD
- LCO: FILE LINK CONTROL INTEGRITY ALL - keep linked files in `datalink.dl_linked_files` table

With datalinker:
- LCO: READ ACCESS DB - make file owned by database
- LCO: WRITE ACCESS BLOCKED
- LCO: RECOVERY YES - make a backup of a file
- LCO: ON UNLINK RESTORE - restore file permissions upon unlink

Missing:
- SQL/MED functions DLURLCOMPLETEWRITE, DLURLPATHWRITE
- SQL/MED function DLREPLACECONTENT
- LCO: WRITE ACCESS ADMIN
- LCO: WRITE ACCESS ADMIN TOKEN
- LCO: ON UNLINK DELETE
- no permissions control of any kind - this needs major considerations
- datalinker daemon
- native postgres URL type + functions
- Transactional File IO functions + file spaces
- foreign server support for file:// URLs (for files on other servers)
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

DATALINK type
=============

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
            
DATALINK functions
==================

Constructors for values of type datalink:

- `DLVALUE(url[,link_type][,comment]) → datalink` (for INSERT)
- `DLNEWCOPY(datalink,tokenp) → datalink` (for UPDATE)
- `DLPREVIOUSCOPY(datalink,tokenp) → datalink` (for UPDATE)

Functions for extracting information from datalink type:

- `DLURLCOMPLETE(datalink) → url`
- `DLURLCOMPLETEONLY(datalink) → url`
- `DLURLPATH(datalink) → path`
- `DLURLPATHONLY(datalink) → path`
- `DLURLSERVER(datalink) → text`
- `DLURLSCHEME(datalink) → text`
- `DLCOMMENT(datalink) → text`
- `DLLINKTYPE(datalink) → {URL,FS}`

See also
--------
- [Slides on design](docs/datalink.pdf) of datalink for Postgres
- tests contain some examples
- https://wiki.postgresql.org/wiki/DATALINK
- [SQL/MED standard](http://www.wiscorp.com/sql20nn.zip)
