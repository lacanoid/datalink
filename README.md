Datalink extension for PostgreSQL
=================================

This attempts to implement some of the SQL/MED datalink functionality on PostgreSQL.
It is very much a prototype and meant for playing around to see if this can be made useful.
It implements a number of SQL/MED specified datalink behaviours.

It comes with a special deamon `pg_datalinker`, which handles all file manipulations,
but the extension can be used without it, albeit with some loss of functionality.
The extension by itself does not perform any file system changes. 

This extension uses a number of advanced Postgres features for implementation,
including transactions, jsonb, event and instead-of triggers, listen/notify, file_fdw, plperlu...
It also requires [pguri](https://github.com/petere/pguri) extension for URL processing and CURL for
integrity checking.
 
Currently, it implements the following:
- SQL/MED DATALINK type, currently defined as domain over jsonb
- SQL/MED DATALINK constructors DLVALUE, DLPREVIOUSCOPY and DLNEWCOPY
- SQL/MED functions DLURLCOMPLETE, DLURLCOMPLETEONLY
- SQL/MED functions DLURLPATH, DLURLPATHONLY
- SQL/MED functions DLURLSCHEME, DLURLSERVER
- DLLINKTYPE function
- DLCOMMENT function
- Setting *link control options* (LCOs) with UPDATE DATALINK.COLUMNS
- Event and other triggers to make all of this 'just work'
- Token generator (uses uuid-ossp)
- PlPerlu interface to [curl](https://curl.se/) via [WWW::Curl](https://metacpan.org/pod/WWW::Curl)
- URI handling functions `uri_get()` and `uri_set()`, uses [pguri](https://github.com/petere/pguri)
- LCO: NO LINK CONTROL - only check for valid URLs and normalize
- LCO: FILE LINK CONTROL INTEGRITY SELECTIVE - check if file exists with CURL HEAD
- LCO: FILE LINK CONTROL INTEGRITY ALL - keep linked files in `datalink.dl_linked_files` table
- Simple datalinker to provide other LCOs, see below

With datalinker:
- LCO: READ ACCESS DB - make file owned by database (chown, chmod)
- LCO: WRITE ACCESS BLOCKED - make file immutable (chattr +i on extfs), forbid datalink column updates
- LCO: WRITE ACCESS ADMIN - make file immutable, allow datalink column updates
- LCO: WRITE ACCESS ADMIN TOKEN - make file immutable, allow column updates only with matching write token
- LCO: RECOVERY YES - make backup copies of linked files
- LCO: ON UNLINK RESTORE - restore file permissions upon unlink
- LCO: ON UNLINK DELETE - delete file when no longer referenced (requires -D option to pg_datalinker)

Missing:
- SQL/MED functions DLURLCOMPLETEWRITE, DLURLPATHWRITE
- SQL/MED function DLREPLACECONTENT
- Foreign server support for file:// URLs (for files on other servers)

Installation
------------

You will need to have 
[WWW::Curl](http://search.cpan.org/~szbalint/WWW-Curl-4.17/lib/WWW/Curl.pm#WWW::Curl::Easy) 
Perl package installed, as it is used by the extension.
On Debian, you can install `libwww-curl-perl` package.

Recent versions also require [pguri](https://github.com/petere/pguri) extension, which must
be installed separately.

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


SQL/MED syntax to set link control options for a column is not supported,
but you can use normal SQL UPDATE on table DATALINK.COLUMNS
to set them instead.

    update datalink.columns
       set link_control='FILE', integrity='ALL',
           read_access='DB', write_access='BLOCKED',
           recovery='YES', on_unlink='RESTORE'
     where table_name='sample_datalinks' and column_name='link';

Currently, only the superuser can change link control options.
            
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
- [Datalink primer](https://github.com/lacanoid/datalink/blob/master/docs/primer.md) 
- [Slides on design](https://github.com/lacanoid/datalink/blob/master/docs/datalink.pdf) of datalink for Postgres (old)
- [Tests contain some examples](test/sql)
- https://wiki.postgresql.org/wiki/DATALINK
- [SQL/MED standard](http://www.wiscorp.com/sql20nn.zip)
- [darold/datalink](https://github.com/darold/datalink) - another implementation of datalink for Postgres by Gilles Darold
