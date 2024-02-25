Datalink extension for PostgreSQL
=================================

This attempts to implement some of the [SQL datalink](https://wiki.postgresql.org/wiki/DATALINK) functionality on PostgreSQL. It is very much a prototype and meant for playing around to see if this can be made useful.
It implements a number of SQL/MED specified datalink behaviours.

DATALINK is special SQL type intended to store references to external files in the database.
Only references to external files are stored in the database, not the content of the files themselves.
Files are addressed with Uniform Resource Locators (URLs).

For detailed documentation see [Datalink manual](https://github.com/lacanoid/datalink/blob/master/docs/README.md).

The standard states: "The purpose of datalinks is to provide a mechanism to synchronize the integrity control, recovery, and access control of the files and the SQL-data associated with them. "

Currently, it implements the following:
- SQL/MED DATALINK type, currently defined as a base type (a variant of jsonb)
- SQL/MED DATALINK constructors DLVALUE, DLPREVIOUSCOPY and DLNEWCOPY
- SQL/MED functions DLURLCOMPLETE, DLURLCOMPLETEONLY
- SQL/MED functions DLURLPATH, DLURLPATHONLY
- SQL/MED functions DLURLSCHEME, DLURLSERVER
- DLLINKTYPE function
- DLCOMMENT function
- Setting of [*link control options*](https://wiki.postgresql.org/wiki/DATALINK#Datalink_attributes_per_SQL_spec) (LCOs) with `UPDATE DATALINK.COLUMNS` or by using type modifier (ie `datalink(52)`)
- Event and other triggers to make all of this 'just work'
- Token generator (uses uuid-ossp)
- LCO: NO LINK CONTROL - only check for valid URLs and normalize them
- LCO: FILE LINK CONTROL INTEGRITY SELECTIVE - check if file exists with CURL HEAD, this also works for web
- LCO: FILE LINK CONTROL INTEGRITY ALL - keep track of linked files in `datalink.dl_linked_files` table
- Simple file manager  to provide other LCOs, see below

With datalinker:
- LCO: READ ACCESS DB - make file owned by database (chown, chmod)
- LCO: WRITE ACCESS BLOCKED - make file immutable (chattr +i on extfs), forbid datalink column updates
- LCO: WRITE ACCESS ADMIN - make file immutable, allow datalink column updates
- LCO: WRITE ACCESS TOKEN - make file immutable, allow column updates only with matching write token
- LCO: RECOVERY YES - backup and restore of linked file contents, point in time recovery (requires -R option to pg_datalinker)
- LCO: ON UNLINK RESTORE - restore file permissions upon unlink
- LCO: ON UNLINK DELETE - delete file when no longer referenced (requires -D option to pg_datalinker)

Missing features:
- SQL/MED functions DLURLCOMPLETEWRITE, DLURLPATHWRITE
- SQL/MED function DLREPLACECONTENT

Extra features not in SQL standard:
- URI handling functions `uri_get()` and `uri_set()`, uses [pguri](https://github.com/lacanoid/pguri)
- PlPerlu interface `curl_get()` to [curl](https://curl.se/) via [WWW::Curl](https://metacpan.org/pod/WWW::Curl)
- Directory and role based permission management for file system access control
- Directory to URL mapping
- Foreign server support for file:// URLs (for files on other postgres_fdw foreign servers)
- Compatibility functions from other databases

This extension uses a number of advanced Postgres features for implementation,
including types, transactions, jsonb, triggers, updatable views, listen/notify, file_fdw, plperlu, advisory locks...
Currently it is fully implemented in high-level languages (no C), mostly in sql, plpgsql and perl.
However it requires [pguri](https://github.com/lacanoid/pguri) extension for URL processing and [curl](https://curl.se/) for
integrity checking. All these together provide a powerful file and web framework within SQL environment.

Installation
------------

You will need to have 
[WWW::Curl](http://search.cpan.org/~szbalint/WWW-Curl-4.17/lib/WWW/Curl.pm#WWW::Curl::Easy) 
Perl package installed, as it is used by the extension.
On Debian, you will need to install `libwww-curl-perl` and also `libdbd-pg-perl` and `libconfig-tiny-perl` packages.

    apt install libwww-curl-perl libdbd-pg-perl libconfig-tiny-perl

Also required is [pguri](https://github.com/lacanoid/pguri) extension, which must
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

This extension lives mostly in the `datalink` schema.
SQL/MED standard compliant functions are installed in `pg_catalog` schema, 
so they are accessible regardless of the search_path.

Event trigger `datalink_event_trigger` is installed. 
It takes care of adding and removing datalink triggers on tables, which contain datalink columns.
Datalink triggers take care of referencing and dereferencing datalinks as values are assigned to datalink columns.

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

If the datalink column already contains data when changing options then there are some limitiations.
It is best to set options in advance, before storing any data.

For further examples see [Datalink manual](https://github.com/lacanoid/datalink/blob/master/docs/README.md).
            
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
- `DLLINKTYPE(datalink) → text`

See also
--------
- [Datalink manual](https://github.com/lacanoid/datalink/blob/master/docs/README.md) 
- [Slides on design](https://github.com/lacanoid/datalink/blob/master/docs/datalink.pdf) of datalink for Postgres (old)
- [Tests contain some examples](test/sql)
- https://wiki.postgresql.org/wiki/DATALINK
- [SQL/MED standard](http://www.wiscorp.com/sql20nn.zip)
- [darold/datalink](https://github.com/darold/datalink) - another implementation of datalink for Postgres by Gilles Darold, 
  check out especially [his presentation](https://github.com/darold/datalink/blob/master/SQL-MED-DATALINK-PgConfAsia2019.pdf).
- [IBM Redbook™ about Datalinks](https://www.redbooks.ibm.com/abstracts/sg246280.html)
