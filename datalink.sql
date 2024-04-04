--
--  datalink
--  version 0.24 lacanoid@ljudmila.org
--
---------------------------------------------------

SET client_min_messages = warning;

COMMENT ON SCHEMA datalink IS 'SQL/MED DATALINK support';
GRANT USAGE ON SCHEMA datalink TO PUBLIC;

---------------------------------------------------
-- url type
---------------------------------------------------

ALTER extension uri SET schema pg_catalog;
-- CREATE DOMAIN url AS text;
CREATE DOMAIN url AS uri;

---------------------------------------------------
-- datalink type
---------------------------------------------------

CREATE DOMAIN dl_linktype AS text;
CREATE DOMAIN dl_token AS uuid;

CREATE DOMAIN file_path AS text;
COMMENT ON DOMAIN file_path IS 'Absolute file system path';
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_noparent  CHECK(value not like all('{../%,%/../%,%/..}'));
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_chars     CHECK(not value ~* '[%*]');
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_absolute  CHECK(length(value)=0 or value like '/%');
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_noserver  CHECK(not value like '%//%');
/*
CREATE DOMAIN pg_catalog.datalink AS jsonb;
COMMENT ON DOMAIN pg_catalog.datalink IS 'SQL/MED DATALINK like type for storing URLs';
*/

CREATE TYPE pg_catalog.datalink;

CREATE OR REPLACE FUNCTION dl_datalink_in(cstring)
 RETURNS datalink LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_in$function$;
 
CREATE OR REPLACE FUNCTION dl_datalink_out(datalink)
 RETURNS cstring LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_out$function$;
 
CREATE OR REPLACE FUNCTION dl_datalink_recv(internal)
 RETURNS datalink LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_recv$function$;
 
CREATE OR REPLACE FUNCTION dl_datalink_send(datalink)
 RETURNS bytea LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_send$function$;
 
CREATE TYPE pg_catalog.datalink (
   INPUT = dl_datalink_in,
   OUTPUT = dl_datalink_out,
   SEND = dl_datalink_send,
   RECEIVE = dl_datalink_recv,
   TYPMOD_IN = varchartypmodin,
   TYPMOD_OUT = varchartypmodout,
   INTERNALLENGTH = VARIABLE,
   ALIGNMENT = int4,
   STORAGE = extended,
   CATEGORY = 'U',
   DELIMITER = ',',
   COLLATABLE = false
);

COMMENT ON TYPE pg_catalog.datalink IS 'SQL/MED DATALINK type for external file references';
create cast (datalink as jsonb) without function; 
-- create cast (datalink as jsonb) without function as implicit;
-- create cast (datalink as jsonb) with inout as implicit;
-- create cast (jsonb as datalink) with inout;

---------------------------------------------------

create or replace function is_local(datalink) returns boolean
language sql immutable strict as $$
 select ($1::jsonb->>'a')::text ilike 'file:///%'
$$;
comment on function is_local(datalink)
     is 'The address of this datalink references a local file';

create or replace function is_valid(datalink) returns boolean
language sql immutable strict as $$
 select case when ($1::jsonb->>'a')::text ilike 'file://%'
             then pg_catalog.dlurlpathonly($1)::datalink.file_path is not null
             else ($1::jsonb->>'a')::uri is not null
             end
$$;
comment on function is_valid(datalink)
     is 'The address of this datalink is a valid URI';

create or replace function is_http_success(datalink) returns boolean
language sql immutable strict as $$
 select cast($1::jsonb->>'rc' as int) between 200 and 299 $$;
comment on function is_http_success(datalink)
     is 'The HTTP return code of this datalink indicates success';

---------------------------------------------------
-- link control options
---------------------------------------------------

create type dl_link_control as enum ( 'NO','FILE' );
create type dl_integrity as enum ( 'NONE','SELECTIVE','ALL' );
create type dl_read_access as enum ( 'FS','DB' );
create type dl_write_access as enum ( 'FS','BLOCKED', 'TOKEN', 'ADMIN' );
create type dl_recovery as enum ( 'NO','YES' );
create type dl_on_unlink as enum ( 'NONE','RESTORE','DELETE' );

create cast (text as dl_link_control) with inout as implicit;
create cast (text as dl_integrity) with inout as implicit;
create cast (text as dl_read_access) with inout as implicit;
create cast (text as dl_write_access) with inout as implicit;
create cast (text as dl_recovery) with inout as implicit;
create cast (text as dl_on_unlink) with inout as implicit;

create domain dl_lco as integer;
comment on type dl_lco is 'Datalink Link Control Options as integer';

CREATE TABLE link_control_options (
  lco dl_lco primary key,
  link_control dl_link_control,
  integrity dl_integrity,
  read_access dl_read_access,
  write_access dl_write_access,
  recovery dl_recovery,
  on_unlink dl_on_unlink
);
comment on table link_control_options is 'Datalink Link Control Options as enums';
grant select on link_control_options to public;

---------------------------------------------------
-- helper functions
---------------------------------------------------

CREATE FUNCTION dl_lco(
  link_control dl_link_control DEFAULT 'NO'::dl_link_control, 
  integrity dl_integrity DEFAULT 'NONE'::dl_integrity, 
  read_access dl_read_access DEFAULT 'FS'::dl_read_access, 
  write_access dl_write_access DEFAULT 'FS'::dl_write_access, 
  recovery dl_recovery DEFAULT 'NO'::dl_recovery, 
  on_unlink dl_on_unlink DEFAULT 'NONE'::dl_on_unlink) 
RETURNS dl_lco
LANGUAGE sql IMMUTABLE
AS $_$
 select cast (trunc(
   (case $2 when 'ALL' then 2 when 'SELECTIVE' then 1 when 'NONE' then 0 else 0 end)
   + 10 * (  
      (case $4
       when 'ADMIN' then 3 when 'TOKEN' then 2 when 'BLOCKED' then 1 when 'FS' then 0
       else 0 end)
      + 4 * (case $3 when 'DB' then 1 when 'FS' then 0 else 0 end)
      + 10 * (
        (case $5 when 'YES' then 1 when 'NO' then 0 else 0 end)
        + (case $6 when 'DELETE' then 2 when 'RESTORE' then 0 when 'NONE' then 0 else 0 end)
      ))
    ) as datalink.dl_lco)
$_$;

COMMENT ON FUNCTION dl_lco(
  dl_link_control,dl_integrity,dl_read_access,dl_write_access,dl_recovery,dl_on_unlink)
IS 'Calculate dl_lco from enumerated options';

---------------------------------------------------
-- find dl_lco for a column
create or replace function dl_lco(regclass regclass,column_name name) returns dl_lco
as $$
 select coalesce(
          case when t.typtypmod > 0 then t.typtypmod-4 end :: datalink.dl_lco,
          case when atttypmod > 0 then atttypmod-4 else 0 end :: datalink.dl_lco
        ) as lco
  from pg_attribute a
  join pg_type t on (t.oid=a.atttypid)
 where attrelid = $1 and attname = $2
   and (t.oid = 'pg_catalog.datalink'::regtype or t.typbasetype = 'pg_catalog.datalink'::regtype)
   and attnum > 0
   and not attisdropped
$$ language sql;
COMMENT ON FUNCTION dl_lco(regclass, name) 
IS 'Find dl_lco for a table column';

---------------------------------------------------
-- find dl_lco for a datalink
CREATE OR REPLACE FUNCTION dl_lco(datalink) RETURNS dl_lco LANGUAGE sql SECURITY DEFINER
AS $function$
select coalesce((select lco
                   from datalink.dl_linked_files f where f.token = ($1::jsonb->>'b')::datalink.dl_token)
               ,0)::datalink.dl_lco
$function$;
COMMENT ON FUNCTION dl_lco(datalink) 
IS 'Find dl_lco for a linked datalink';

---------------------------------------------------

CREATE FUNCTION link_control_options(dl_lco) 
RETURNS link_control_options
LANGUAGE sql IMMUTABLE AS $_$
select * from datalink.link_control_options where lco = $1
$_$;

COMMENT ON FUNCTION link_control_options(dl_lco)
IS 'Calculate link_control_options from dl_lco';

---------------------------------------------------

CREATE OR REPLACE FUNCTION link_control_options(datalink)
 RETURNS link_control_options
 LANGUAGE sql IMMUTABLE
AS $function$
select lco.*
  from datalink.link_control_options lco
 where lco.lco = datalink.dl_lco($1)
$function$
;

COMMENT ON FUNCTION link_control_options(datalink)
IS 'Get link_control_options for a linked datalink';

---------------------------------------------------
-- init options table
---------------------------------------------------

-- initialize valid link control options
insert into link_control_options 
with l as (
select datalink.dl_lco(link_control=>lc,integrity=>itg,
                       read_access=>ra,write_access=>wa,
                       recovery=>rec,on_unlink=>unl
                       ),* 
from
    unnest(array['NO','FILE']) as lc,
    unnest(array['NONE','SELECTIVE','ALL']) as itg,
    unnest(array['FS','DB']) as ra,
    unnest(array['FS','BLOCKED','TOKEN','ADMIN']) as wa,
    unnest(array['NO','YES']) as rec,
    unnest(array['NONE','RESTORE','DELETE']) as unl
)
-- valid option combinations per SQL/MED 2011 
select distinct * from l
 where lc='NO'    and itg='NONE'      and ra='FS' and wa='FS' and unl='NONE' and rec='NO'
    or lc='FILE'  and itg='SELECTIVE' and ra='FS' and wa='FS' and unl='NONE' and rec='NO'
    or lc='FILE'  and itg='ALL'       and (
          ra='FS' and wa='FS'      and unl='NONE' and rec='NO'
       or ra='FS' and wa='BLOCKED' and unl='RESTORE'
       or ra='DB' and wa<>'FS'     and unl<>'NONE'
    )
--    and not (rec='NO' and unl='DELETE')
 order by dl_lco
;

-- is class adminable (owned or we are superuser)
CREATE FUNCTION has_class_privilege(my_class regclass) RETURNS boolean
    LANGUAGE sql
    AS $_$
select case
       when current_setting('is_superuser')::boolean then true
       when (select rolsuper
               from pg_roles where oid = current_role::regrole) then true
       else (select relowner = current_role::regrole
               from pg_class where oid = $1)
       end
$_$;

---------------------------------------------------
-- views
---------------------------------------------------

CREATE VIEW dl_columns AS
 SELECT c.relowner::regrole AS table_owner,
    s.nspname AS schema_name,
    c.relname AS table_name,
    a.attname AS column_name,
    dl_lco(c.oid::regclass,a.attname::name) AS lco,
    a.attnum,
--    a.atttypmod,
    a.attoptions,
    a.attfdwoptions,
    c.oid::regclass AS regclass,
    a.atttypid::regtype as regtype,
    col_description(c.oid, (a.attnum)::integer) AS comment
   FROM pg_class c
   JOIN pg_namespace s ON (s.oid = c.relnamespace)
   JOIN pg_attribute a ON (c.oid = a.attrelid)
   LEFT JOIN pg_attrdef def ON (c.oid = def.adrelid AND a.attnum = def.adnum)
   LEFT JOIN pg_type t ON (t.oid = a.atttypid)
  WHERE (t.oid = 'pg_catalog.datalink'::regtype OR t.typbasetype = 'pg_catalog.datalink'::regtype)
    AND (c.relkind = 'r'::"char" AND a.attnum > 0 AND NOT a.attisdropped)
  ORDER BY s.nspname, c.relname, a.attnum;

---------------------------------------------------

CREATE VIEW columns AS
SELECT
    cast(regclass as text) as table_name,
    column_name,
    lco.link_control,
    lco.integrity,
    lco.read_access,
    lco.write_access,
    lco.recovery,
    lco.on_unlink
 FROM datalink.dl_columns c
 LEFT JOIN link_control_options lco ON lco.lco=coalesce(c.lco,0)
WHERE datalink.has_class_privilege(regclass);

COMMENT ON VIEW columns
 IS 'Current link control options for datalink dl_columns. You can set them here.';

grant select on columns to public;
grant update on columns to public;

---------------------------------------------------

CREATE FUNCTION dl_trigger_advice(
    OUT owner name, OUT regclass regclass, 
    OUT valid boolean, OUT needed boolean,
    OUT identifier name, OUT links bigint, OUT mco int, OUT sql_advice text) 
    RETURNS SETOF record
    LANGUAGE sql
    AS $$
WITH
 triggers AS (
         SELECT c0_1.oid,
                t0.tgname
           FROM pg_trigger t0
           JOIN pg_class c0_1 ON t0.tgrelid = c0_1.oid
          WHERE t0.tgname = '~RI_DatalinkTrigger'::name
      AND datalink.has_class_privilege(c0_1.oid)
 ),
 classes AS (
         SELECT dl_columns.regclass,
                count(*) AS count,
                max(dl_columns.lco) AS mco
           FROM datalink.dl_columns dl_columns
          WHERE datalink.has_class_privilege(dl_columns.regclass)
          GROUP BY dl_columns.regclass
 ),
 dl_triggers AS (
         SELECT c0.relowner::regrole::name AS owner,
                (COALESCE(c.regclass, t.oid))::regclass AS regclass,
                COALESCE(c.count, (0)::bigint) AS links,
                c.mco,
                t.tgname
           FROM triggers t
           FULL JOIN classes c ON (t.oid = c.regclass)
           JOIN pg_class c0 ON (c0.oid = COALESCE(c.regclass, t.oid))
          ORDER BY COALESCE(c.regclass, t.oid)::regclass::text
 )
SELECT 
    owner,
    regclass AS regclass,
--    not (tgname is null or links = 0) as valid,
    (tgname is null and mco=0) or (tgname is not null and mco>0) as valid,
    links>0 and mco>0 as needed,
    tgname AS identifier,
    links,
    mco,
    COALESCE('DROP TRIGGER IF EXISTS ' || quote_ident(tgname) 
             || ' ON ' || regclass::text || '; ', '') ||
    COALESCE('DROP TRIGGER IF EXISTS ' || quote_ident(tgname||'2') 
             || ' ON ' || regclass::text || E'; \n', '') ||
    case when links>0 and mco > 0 then
     COALESCE(('CREATE TRIGGER "~RI_DatalinkTrigger" BEFORE INSERT OR UPDATE OR DELETE ON '
               ||  regclass::text) 
               || E' FOR EACH ROW EXECUTE PROCEDURE datalink.dl_trigger_table();\n', '')
         ||
     COALESCE(('CREATE TRIGGER "~RI_DatalinkTrigger2" BEFORE TRUNCATE ON '
               ||  regclass::text) 
               || ' FOR EACH STATEMENT EXECUTE PROCEDURE datalink.dl_trigger_table();', '') 
    else ''
    end AS sql_advice
   FROM dl_triggers
$$;

---------------------------------------------------
-- linked files
---------------------------------------------------
CREATE TYPE file_link_state AS ENUM (
    'LINK','LINKED','ERROR','UNLINK'
);
create table dl_linked_files (
  token dl_token not null unique,
  txid xid8 not null default pg_current_xact_id(),
  state file_link_state not null default 'LINK',
  cons "char",
  lco dl_lco not null references datalink.link_control_options,
  attrelid regclass not null,
  attnum smallint not null,
  path file_path primary key,
  address text[] unique,
  size bigint,
  mtime timestamptz,
  fstat jsonb,
  info jsonb,
  err jsonb
);
-- index for datalinker
create index dl_linked_files_txid on dl_linked_files (txid) 
 where state = ANY ('{LINK,UNLINK}'::file_link_state[]);

create view linked_files as
select path,state,
       lco.read_access as read_access,
       lco.write_access as write_access,
       lco.recovery,
       lco.on_unlink,
       a.attrelid::regclass as regclass,
       a.attname,
       c.relowner::regrole as owner,
       jsonb_pretty(lf.err)::json as err
  from datalink.dl_linked_files  lf
  join datalink.link_control_options lco on lco.lco=coalesce(lf.lco,0)
  join pg_class c on c.oid = lf.attrelid
  join pg_attribute a using (attrelid,attnum)
 where datalink.has_class_privilege(attrelid);
comment on view linked_files
     is 'Currently linked files';

grant select on linked_files to public;

---------------------------------------------------

CREATE OR REPLACE FUNCTION stat(file_path file_path,
   OUT dev bigint, OUT inode bigint, OUT mode integer, OUT typ "char", OUT nlink integer,
   OUT uid integer, OUT gid integer,
   OUT rdev integer, OUT size numeric, 
   OUT atime numeric,
   OUT mtime numeric, 
   OUT ctime numeric,
   OUT blksize integer, OUT blocks bigint)
   RETURNS record
  LANGUAGE plperlu
   STRICT
   AS $function$
#use Date::Format;

my ($filename) = @_;
unless(-e $filename) { return undef; }
my (@s) = lstat($filename);
my $typs="?pc?d?b?-?l?s???"; # file types as shown by ls(1)
return {
 'dev'=>$s[0],'inode'=>$s[1],
 'mode'=>($s[2] & 07777),
 'typ'=>substr($typs,(($s[2] & 0170000)>>12),1),
 'nlink'=>$s[3],
 'uid'=>$s[4],'gid'=>$s[5],
 'rdev'=>$s[6],'size'=>$s[7],
# 'atime'=>time2str("%C",$s[8]),'mtime'=>time2str("%C",$s[9]),'ctime'=>time2str("%C",$s[10]),
 'atime'=>$s[8],'mtime'=>$s[9],'ctime'=>$s[10],
 'blksize'=>$s[11],'blocks'=>$s[12]
};
$function$;
COMMENT ON FUNCTION stat(file_path) IS 'Return info record from stat(2)';

-- return most appropriate path to a file 
-- return NULL if file does not exist
create or replace function filepath(datalink) returns text as $$
declare p text;
begin
  if datalink.is_local($1) then
    p := dlurlpathwrite($1);
    if (datalink.stat(p)).size is not null then return p; end if;
    p := dlurlpathonly($1);
    if (datalink.stat(p)).size is not null then return p; end if;
  end if;
  return null;
end
$$ language plpgsql strict;

---------------------------------------------------
-- link a file to SQL
create function dl_file_link(file_path file_path,
                             my_token dl_token,
			     my_cons "char",
                             my_lco dl_lco,
                             my_regclass regclass,my_attname name)
returns boolean
language plpgsql as
$$
declare
 r record;
 fstat jsonb;
 my_address text[];
 my_attnum smallint;
 my_mtime timestamptz;
 my_size bigint;
begin
-- raise notice 'DATALINK LINK:%:%',format('%s.%I',regclass::text,attname),file_path;
 raise notice 'DATALINK LINK:%',file_path;

-- if (datalink.link_control_options(my_lco)).write_access >= 'BLOCKED' then
   if not datalink.has_valid_prefix(file_path) THEN
        raise exception 'DATALINK EXCEPTION - referenced file not valid' 
              using errcode = 'HW007',
                    detail = format('unknown path prefix for "%s"',file_path),
                    hint = 'run "dlfm add" to add prefixes'
                    ;
   end if;
-- end if;
 fstat := row_to_json(datalink.stat(file_path))::jsonb;
 if fstat is null then
   fstat := row_to_json(datalink.stat(file_path||'#'||my_token))::jsonb;
 end if;
 if fstat is null then
      raise exception 'DATALINK EXCEPTION - referenced file not valid' 
            using errcode = 'HW007',
                  detail = format('stat failed for "%s"',file_path);
 end if;
 if fstat->>'typ' not in ('-','d') then 
      raise exception 'DATALINK EXCEPTION - referenced file not valid' 
            using errcode = 'HW007',
                  detail = format('file "%s" is neither file nor directory, but "%s"',file_path,fstat->>'typ');
 end if;

 my_address := array[fstat->>'dev',fstat->>'inode'];
 my_size := fstat->>'size';
 my_mtime := to_timestamp(cast(fstat->>'mtime' as double precision));

 select attnum
   from pg_attribute where attname=my_attname and attrelid=my_regclass
   into my_attnum;
 select * into r
   from datalink.dl_linked_files
   join pg_attribute a using (attrelid,attnum)
  where path = file_path or address = my_address
    for update;
 if not found then
   insert into datalink.dl_linked_files (token,path,lco,attrelid,attnum,address,size,mtime,cons)
   values (my_token,file_path,my_lco,my_regclass,my_attnum,my_address,my_size,my_mtime,my_cons);
   notify "datalink.linker_jobs"; 
   return true;
 else -- found in dl_linked_files
  -- this is needed to eliminate problems during pg_restore
  if r.token = my_token and r.path = file_path and r.lco = my_lco and
     r.attrelid = my_regclass and r.attnum = my_attnum then
    raise warning 'DATALINK WARNING - external file possibly already linked' 
      using detail = format('from %s.%I as ''%s''',r.attrelid::text,r.attname,r.path);
  end if;

  -- already linked ?
  if r.state in ('LINK','LINKED') then
    raise exception 'DATALINK EXCEPTION - external file already linked' 
      using errcode = 'HW002', 
      detail = format('from %s.%I as ''%s''',r.attrelid::text,r.attname,r.path);

  -- scheduled for unlinking by datalinker but not processed yet
  elsif r.state in ('UNLINK') then
     if r.lco is distinct from my_lco
     then
        raise exception 'DATALINK EXCEPTION - external file already linked' 
          using errcode = 'HW002', 
          detail = format('Cannot change link control options in update');
     end if;
     
     if r.token is not distinct from my_token
     then -- same file and protection
        update datalink.dl_linked_files
           set state='LINKED',
               attrelid=my_regclass,
               attnum=my_attnum,
               address=my_address,
               size=my_size,
               mtime=my_mtime,
	             cons=my_cons
         where path = file_path and state='UNLINK';
        return true;
     else -- relink
        update datalink.dl_linked_files
           set state='LINK',
               token=my_token,
               attrelid=my_regclass,
               attnum=my_attnum,
               address=my_address,
               size=my_size,
               mtime=my_mtime,
	             cons=my_cons
         where path = file_path and state='UNLINK';
        return true;

      --  raise exception 'DATALINK EXCEPTION - external file already linked' 
      --  using errcode = 'HW002', 
      --  detail = format('file is waiting for unlink ''%s'' by datalinker process',r.path);

     end if; -- token changed

  else -- other link state
      raise exception 'DATALINK EXCEPTION' 
            using errcode = 'HW000', 
                  detail = format('unknown link state %s',r.state);
  end if;
 end if; -- if found
end
$$;
revoke execute on function dl_file_link from public;

---------------------------------------------------
-- unlink a file from SQL
create function dl_file_unlink(file_path file_path)
returns boolean as
$$
declare
 r record;
begin
 raise notice 'DATALINK UNLINK:%',file_path;

 select * into r
   from datalink.dl_linked_files
   join datalink.link_control_options using (lco)
  where path = file_path
    for update of dl_linked_files;
 if not found then
        raise exception 'DATALINK EXCEPTION - external file not linked' 
        using errcode = 'HW001', 
              detail = file_path;
 else
  if r.state = 'LINK' then
   update datalink.dl_linked_files
      set state = 'UNLINK',
          token = cast(info->>'b' as datalink.dl_token),
          lco   = cast(info->>'lco' as datalink.dl_lco)
    where path  = file_path and info is not null
      and state = 'LINK';

   delete from datalink.dl_linked_files
    where path  = file_path and info is null
      and state = 'LINK';

  elsif r.state = 'LINKED' then
   if r.on_unlink = 'DELETE' then
    if not datalink.has_file_privilege(file_path,'delete',false) then
     raise exception e'DATALINK EXCEPTION - DELETE permission denied on directory\nPATH:  %',file_path 
           using errcode = 'HW005', 
                 detail = 'delete permission is required on directory',
                 hint = 'add appropriate entry in table datalink.access';
    end if;
   end if;

   update datalink.dl_linked_files
      set state = 'UNLINK'
    where path  = file_path and state = 'LINKED';

  elsif r.state = 'ERROR' then
   delete from datalink.dl_linked_files
    where path  = file_path
      and state = 'ERROR';

  elsif r.state = 'UNLINK' then
        raise exception 'DATALINK EXCEPTION - waiting for datalinker' 
              using errcode = 'HW000', 
                    detail = format('file is ''%s'' waiting for unlink by the datalinker process',r.path),
                      hint = 'start datalinker with "dlfm start"';

  else
      raise exception 'DATALINK EXCEPTION' 
            using errcode = 'HW000', 
                  detail = format('unknown link state %s',r.state);
  end if;
 end if;
 notify "datalink.linker_jobs";
 return true;
end
$$ language plpgsql strict;
revoke execute on function dl_file_unlink from public;

---------------------------------------------------
-- uri functions
---------------------------------------------------
/*
CREATE OR REPLACE FUNCTION uri_get(url text, part text)
 RETURNS text
  LANGUAGE plperlu
  AS $function$
use URI;
use File::Basename;

my $u=URI->new($_[0]);
my $part=$_[1]; lc($part);

# common
 if($part eq 'path') { return $u->path; }
 if($part eq 'fragment') { return $u->fragment; }
my $scheme=$u->scheme;
 if($part eq 'scheme') { return $u->has_recognized_scheme?$scheme:undef; }

my $v = eval {
 if($part eq 'authority') { return $u->authority; }
 if($part eq 'user') { return $u->user(); }
 if($part eq 'userinfo') {
  if($scheme eq 'file') { my $r=$u->host; $r=~s/@.*$//; return $r?$r:undef; }
  return $u->userinfo();
 }
 if($part eq 'host') { my $r=$u->host; $r=~s/^.*@//; return $r; }
 if($part eq 'server') { return $u->host; }
 if($part eq 'domain') { my $d = $u->host; $d=~s|^[^\.]*\.||; return $d; }
 if($part eq 'port') { return $u->port; }
 if($part eq 'host_port') { return $u->host_port(); }
 if($part eq 'dirname') { return dirname($u->path); }
if(!($scheme eq 'data')) {
 if($part eq 'basename') { return basename($u->path()); }
 if($part eq 'filename') { return (fileparse($u->path()))[0]; }
 if($part eq 'media_type') { return undef; }
 if($part eq 'dirname') { return dirname($u->path); }
} else { # data:
 if($part eq 'basename') { return undef; }
 if($part eq 'filename') { return undef; }
 if($part eq 'media_type') { return $u->media_type; }
 if($part eq 'dirname') { return $u->media_type; }
}
 if($part eq 'dir') { return $u->dir; }
 if($part eq 'file') { return $u->file; }
 if($part eq 'suffix') { return (fileparse($u->path()))[2]; }
 if($part eq 'path_query') { return $u->path_query(); }
 if($part eq 'query') { return $u->query(); }
 if($part eq 'query_form') { return $u->query_form(); }
 if($part eq 'query_keywords') { return $u->query_keywords(); }
 if($part eq 'token') { return $u->fragment(); }
 if($part eq 'canonical') {
  if($u->query() eq '') { $u->query(undef); }
  if($u->fragment() eq '') { $u->fragment(undef); }
  my $c = $u->canonical; return "$c";
 }
 else { elog(ERROR,"Unknown part '$part'."); }
};
if($part eq 'canonical') { return $u->canonical->as_string; }
return $v;

elog(ERROR,"Unknown part '$_[1]'.");
return undef;

$function$
;
*/
CREATE OR REPLACE FUNCTION uri_get(url text, part text)
 RETURNS text LANGUAGE SQL immutable strict AS $$
  select datalink.uri_get($1::uri,$2)
$$;

COMMENT ON FUNCTION uri_get(text,text) IS 'Get (extract) parts of URI';
---------------------------------------------------

CREATE OR REPLACE FUNCTION uri_get(url uri, part text)
  RETURNS text LANGUAGE sql IMMUTABLE STRICT AS $$
   select case part
          when 'scheme' then uri_scheme($1)
          when 'server' then uri_host($1)
          when 'userinfo' then uri_userinfo($1)
          when 'host' then uri_host($1)
          when 'path' then uri_unescape(uri_path($1))
          when 'basename' then nullif(to_json(uri_path_array($1))->>-1,'')
          when 'dirname' then nullif(to_json(uri_path_array($1))->>-1,'')
          when 'query' then uri_query($1)
          when 'fragment' then uri_fragment($1)
          when 'token' then uri_unescape(uri_fragment($1))
          when 'canonical' then uri_normalize($1)::text
          -- without fragment
          when 'only' then regexp_replace(uri_normalize($1)::text,'#.*','')
          end $$;
COMMENT ON FUNCTION uri_get(uri,text) IS 'Get (extract) parts of URI';

CREATE OR REPLACE FUNCTION uri_get(link datalink, part text)
 RETURNS text LANGUAGE sql IMMUTABLE STRICT AS $$
  select datalink.uri_get($1::jsonb->>'a',$2) $$;

COMMENT ON FUNCTION uri_get(datalink,text) IS 'Get (extract) parts of datalink URI';

---------------------------------------------------

CREATE OR REPLACE FUNCTION uri_set(url uri, part text, val text)
 RETURNS text
  LANGUAGE plperlu
  AS $function$
  use URI;
  my $u=$_[0];
  my $part=$_[1]; lc($part);
  my $v=$_[2];
  if($part eq 'src') { $u = URI->new_abs($v,$u); return $u->as_string; }
  $u = URI->new($u);
  if($part eq 'scheme') { $u->scheme($v); }
  elsif($part eq 'server') {  $u->host($v); }
  elsif($part eq 'authority') {  $u->authority($v); }
  elsif($part eq 'path_query') {  $u->path_query($v); }
  elsif($part eq 'userinfo') {  $u->userinfo($v); }
  elsif($part eq 'host') {  $u->host($v); }
  elsif($part eq 'port') {  $u->port($v); }
  elsif($part eq 'host_port') {  $u->host_port($v); }
  elsif($part eq 'path') {  $u->path($v); }
  elsif($part eq 'basename') {  
    my $p=$u->path(); $p=~s|/[^/]*$||; $p.='/'.$v; $u->path($p);
  }
  elsif($part eq 'query') {  $u->query($v); }
  elsif($part eq 'query_form') {  $u->query_form($v); }
  elsif($part eq 'query_keywords') {  $u->query_keywords($v); }
  elsif($part eq 'fragment') {  $u->fragment($v); }
  elsif($part eq 'token') {  $u->fragment($v); }
  else { elog(ERROR,"Unknown part '$part'."); }
  return $u->as_string;
  $function$
  ;

COMMENT ON FUNCTION uri_set(uri,text,text) IS 'Set (replace) parts of URI';

---------------------------------------------------
CREATE OR REPLACE FUNCTION iri(iri text) RETURNS text language sql strict as $$
 SELECT datalink.uri_set('/','src',$1) $$;
COMMENT ON FUNCTION iri(text)
     IS 'Convert IRI (unicode characters) to URI (escaped)';


---------------------------------------------------
-- event triggers
---------------------------------------------------

CREATE FUNCTION dl_trigger_event() RETURNS event_trigger
LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
 obj record;
 js json;
begin
-- RAISE NOTICE 'DATALINK EVENT [%] TAG [%] ROLE % %', tg_event, tg_tag, current_role, current_setting('is_superuser');

 if tg_event = 'ddl_command_end' then

 if tg_tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO','ALTER TABLE') 
 then
  -- update triggers on tables with datalinks
   for obj in select * from datalink.dl_trigger_advice()
   where not valid
   loop
     RAISE NOTICE 'DATALINK DDL:% on %','TRIGGER',obj.regclass;
     execute obj.sql_advice;
   end loop;
        -- mark datalink triggers as internal
     update pg_trigger 
        set tgisinternal = true  
      where tgisinternal is distinct from true 
        and tgname like '%RI_DatalinkTrigger%';

   if tg_tag = 'ALTER TABLE' then
    with info as (
      select classid::regclass,objid,objsubid,
             command_tag,object_type,schema_name,object_identity,
             in_extension
        from pg_event_trigger_ddl_commands()
    )
    select json_agg(row_to_json(info)) 
       from info 
       into js;
--    RAISE NOTICE 'ALTER TABLE %',js;
   end if; -- alter table
      
   -- check if there are invallid link control options
   if exists(
        select regclass from datalink.dl_columns 
        where lco not in (select lco from datalink.link_control_options)
      ) then
      raise exception 'DATALINK EXCEPTION' 
            using errcode = 'HW000',
            detail = format('Invalid link control options'),
            hint = 'see table datalink.link_control_options for valid link control options';
   end if;
 end if; -- tg_tag in (...)

 elsif tg_event = 'sql_drop' then
  -- unlink files referenced by dropped tables
  for obj in
   select *
     from datalink.dl_linked_files f
    where attrelid in 
      (select tdo.objid
         from pg_event_trigger_dropped_objects() tdo
        where object_type = 'table'
       )
    order by txid
  loop
    perform datalink.dl_file_unlink(obj.path);
  end loop;

  -- unlink files referenced by dropped dl_columns
  for obj in
    select *
      from
      (select objid::regclass as regclass, objsubid as attnum,
              address_names[3] as attname
         from pg_event_trigger_dropped_objects()
        where object_type = 'table column'
       ) as tdo
      join datalink.dl_linked_files f on f.attrelid=tdo.regclass and f.attnum=tdo.attnum
     order by txid
  loop
    perform datalink.dl_file_unlink(obj.path);
  end loop;

end if;

end
$$;
alter function dl_trigger_event() owner to postgres;

---------------------------------------------------

create event trigger datalink_event_trigger_end on ddl_command_end
when tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO','ALTER TABLE') 
execute procedure dl_trigger_event();

create event trigger datalink_event_trigger_drop
on sql_drop execute procedure dl_trigger_event();

---------------------------------------------------
-- token generator
---------------------------------------------------

CREATE OR REPLACE FUNCTION uuid_generate_v4() RETURNS uuid
    LANGUAGE c PARALLEL SAFE STRICT
    AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$;

CREATE FUNCTION dl_newtoken() RETURNS dl_token LANGUAGE sql
    AS $$select cast(datalink.uuid_generate_v4() as datalink.dl_token);$$;

---------------------------------------------------
-- SQL/MED datalink functions
---------------------------------------------------

CREATE FUNCTION pg_catalog.dlvalue(url text, linktype dl_linktype DEFAULT NULL, comment text DEFAULT NULL) 
RETURNS datalink
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
 my_dl datalink;
 my_uri text;
 my_type text;
begin
 -- convert IRI to URI
 if linktype = 'IRI' THEN
   url := datalink.iri(url); linktype := 'URL';
 end if;
 my_uri := coalesce(my_uri,url);
 my_type := coalesce(linktype, case when url like '/%' then 'FS' else 'URL' end);
 -- try http to file mapping
 if my_type = 'URL' then 
   select dirpath||uri_unescape(substr(url,length(dirurl::text)+1))
     from datalink.directory
    where dirurl is not null and url like dirurl||'%'
    order by length(dirurl::text) desc limit 1
     into my_uri;
   if my_uri is not null then my_type:='FS'; end if;
 end if;
 my_uri := coalesce(my_uri,url);
 -- linktype is a named directory
 if my_type not in ('URL','FS') then 
  select dirpath||coalesce(my_uri,'') from datalink.directory where dirname=my_type into my_uri;
  if not found then 
        raise exception 'DATALINK EXCEPTION - nonexistent directory' 
              using errcode = 'HW005',
                    detail = format('directory "%s" does not exist',linktype),
                    hint = 'perhaps you need to add it to datalink.directory';
  end if;
 end if;
 if my_type is distinct from 'URL' then -- like type is file or directory
   -- a file path
   my_uri := my_uri::datalink.file_path; -- validate path
   my_uri := format('file://%s',replace(replace(uri_escape(''||my_uri),'%2F','/'),'%23','#'));
 end if;
 if my_uri is null or length(my_uri)<=0 then  -- only comment
   return case when comment is not null then jsonb_build_object('c',comment) end;
 end if;
 my_uri := my_uri::datalink.url; -- validate URL
 my_dl  := jsonb_build_object('a',datalink.uri_get(my_uri::datalink.url,'canonical'));
 if comment is not null then
   my_dl:=jsonb_set(my_dl::jsonb,array['c'],to_jsonb(comment));
 end if;
 if my_type not in ('URL','FS') then
    my_dl:=jsonb_set(my_dl::jsonb,array['t'],to_jsonb(my_type));
 end if;
 return my_dl;
end;
$$;

COMMENT ON FUNCTION pg_catalog.dlvalue(text,dl_linktype,text) 
IS 'SQL/MED - Construct a DATALINK value';

CREATE FUNCTION pg_catalog.dlvalue(url text, url_base datalink, comment text DEFAULT NULL) 
RETURNS datalink
    LANGUAGE sql IMMUTABLE
    AS $$select dlvalue(datalink.uri_set(($2::jsonb->>'a')::uri,'src',$1),null::datalink.dl_linktype,coalesce($3,dlcomment($2)))$$;

COMMENT ON FUNCTION pg_catalog.dlvalue(text,datalink,text) 
IS 'SQL/MED - Construct a DATALINK value relative to another DATALINK value';


---------------------------------------------------
-- SQL/MED update functions
---------------------------------------------------

CREATE FUNCTION pg_catalog.dlpreviouscopy(link datalink, has_token integer default 1) RETURNS datalink
    LANGUAGE plpgsql
    AS $_$
declare
 token  datalink.dl_token;
 l1     datalink;
 t1     text;
 u1     text;
begin 
 l1 := link;
 u1 := link::jsonb->>'a';
 t1 := link::jsonb->>'o';
 if has_token > 0 then
  t1 := coalesce(t1,datalink.uri_get(u1,'token'));
  if t1 is not null then
    begin
      token := t1::datalink.dl_token;
    exception
      when sqlstate '22P02' then
        raise exception 'DATALINK EXCEPTION - invalid write token'
        using errcode = 'HW004', 
              detail = SQLERRM;
      when others then
        raise exception 'Error code: % name: %',SQLSTATE,SQLERRM;
    end;
    u1 := datalink.uri_set(u1::datalink.url,'token',null);
    link := jsonb_set(link::jsonb,'{a}',to_jsonb(u1));
  end if;
  if token is null then token := link::jsonb->>'b'; end if;
  if token is null then token := datalink.dl_newtoken() ; end if;
  link := jsonb_set(link::jsonb,'{b}',to_jsonb(token));
  link := link::jsonb - 'o';
 else -- not has_token
   select lead(r.link) over(order by rev desc)
     from datalink.revisions(l1) r
    where r.link::jsonb->>'b' = l1::jsonb->>'b' -- limit 1
     into link;
       if link is null then link := l1; end if;
 end if; -- has_token
   link := jsonb_set(link::jsonb,'{k}',to_jsonb('p'::text));
 return link;
end
$_$;
COMMENT ON FUNCTION pg_catalog.dlpreviouscopy(link datalink, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value indicating that the previous version of the file should be restored';

CREATE FUNCTION pg_catalog.dlpreviouscopy(url text, has_token integer default 1) RETURNS datalink
    LANGUAGE sql
    AS $_$select pg_catalog.dlpreviouscopy(pg_catalog.dlvalue($1),$2)$_$;
COMMENT ON FUNCTION pg_catalog.dlpreviouscopy(url text, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value indicating that the previous version of the file should be restored';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlnewcopy(link datalink, has_token integer default 1) RETURNS datalink
    LANGUAGE plpgsql STRICT
    AS $_$
declare
 token datalink.dl_token;
 t1 text;
 u1 text;
begin 
  u1 := link::jsonb->>'a';
  if has_token > 0 then
    t1 := coalesce(link::jsonb->>'b',datalink.uri_get(u1,'token'));
    if t1 is not null then 
      link := jsonb_set(link::jsonb,'{o}',to_jsonb(t1));
    end if;
  end if;
  u1 := datalink.uri_set(u1::datalink.url,'token',null);
  link := jsonb_set(link::jsonb,'{a}',to_jsonb(u1));
    -- generate new token
  token := datalink.dl_newtoken();  
  link := jsonb_set(link::jsonb,'{b}',to_jsonb(token));
  link := jsonb_set(link::jsonb,'{k}',to_jsonb('n'::text));
 return link;
end
$_$;
COMMENT ON FUNCTION pg_catalog.dlnewcopy(link datalink, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value indicating that the referenced file content has changed';

CREATE FUNCTION pg_catalog.dlnewcopy(url text, has_token integer default 1) RETURNS datalink
    LANGUAGE sql
    AS $_$select pg_catalog.dlnewcopy(pg_catalog.dlvalue($1),$2)$_$;
COMMENT ON FUNCTION pg_catalog.dlnewcopy(url text, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value indicating that the referenced file content has changed';

---------------------------------------------------
-- referential integrity triggers
---------------------------------------------------

CREATE FUNCTION dl_datalink_ref(link datalink, link_options dl_lco, regclass regclass, column_name name) 
RETURNS datalink
LANGUAGE plpgsql
    AS $_$
declare
 lco datalink.link_control_options;
 r record;
 has_token integer;
 url text; cons "char";
begin 
 url := format('%s%s',$1::jsonb->>'a','#'||($1::jsonb->>'b'));
 url := url::datalink.url;
-- raise exception 'DATALINK: dl_datalink_ref(''%'',%,%,%)',url,$2,$3,$4;

 has_token := 0;
 if link_options > 0 then
  lco = datalink.link_control_options(link_options);
  if lco.integrity <> 'NONE' then
    -- check if this is a file not a link
    if lco.integrity = 'ALL' and dlurlscheme(link)<>'FILE' then
        raise exception 'DATALINK EXCEPTION - invalid datalink construction' 
              using errcode = 'HW005',
                    detail = 'INTEGRITY ALL can only be used with file URLs',
                    hint = 'make sure you are using a file: URL scheme';
    end if;
    -- check if datalinker in needed and running
    if lco.integrity = 'ALL' and link_options>10 then
      if not datalink.has_datalinker() then
        raise warning 'DATALINK WARNING - datalinker required' 
              using errcode = '57050',
--                    detail = 'datalinker process is not available',
                    hint = 'make sure pg_datalinker process is running to finalize your commits';
      end if;
    end if;

    if lco.integrity = 'ALL' then has_token := 1; end if;
    -- check if reference exists
    r := datalink.curl_get(url,1);
    if not r.ok and dlurlscheme(link) = 'FILE' and url ~ '#' then 
      url := replace(url,'#','%23');
      r := datalink.curl_get(url,1);
    end if;
    if not r.ok and dlurlscheme(link) = 'FILE' then
      r.ok := not (datalink.stat(dlurlpathonly(link))).inode is null;
    end if;

    if not r.ok then
      raise exception e'DATALINK EXCEPTION - referenced file does not exist\nURL:  %',url 
            using errcode = 'HW003', 
                  detail = format('CURL error %s - %s',r.rc,r.error),
                  hint = 'make sure URL is correct and referenced file actually exists';
    end if;
    -- store HTTP response code if one was returned
    if r.rc > 0 then
      link := jsonb_set(link::jsonb,'{rc}',to_jsonb(r.rc));
    end if;
  end if; -- file link control,  

  link := link::jsonb - 'o'; cons := link::jsonb ->> 'k';
  link := dlpreviouscopy(link,has_token)::jsonb - 'k';

  if lco.integrity = 'ALL' and dlurlscheme($1)='FILE' then
      if lco.on_unlink = 'DELETE' THEN
        if not datalink.has_file_privilege(dlurlpathonly(link),'delete',false) THEN
          raise exception e'DATALINK EXCEPTION - DELETE permission denied on directory\nURL:  %',url 
                using errcode = 'HW005', 
                      detail = 'delete permission is required on directory',
                      hint = 'add appropriate entry in table datalink.access';
        end if;
      end if;
      perform datalink.dl_file_link(dlurlpathonly(link),(link::jsonb->>'b')::datalink.dl_token,cons,link_options,regclass,column_name);
  end if; -- integrity all

 end if; -- link options
 return link;
end$_$;

---------------------------------------------------

CREATE FUNCTION dl_datalink_unref(link datalink, link_options dl_lco, regclass regclass, column_name name) 
RETURNS datalink
    LANGUAGE plpgsql
    AS $_$
declare
 lco datalink.link_control_options;
begin
-- raise notice 'DATALINK: dl_datalink_unref(''%'',%,%,%)',dlurlcomplete($1),$2,$3,$4;

 if link_options > 0 then
  lco = datalink.link_control_options(link_options);

  if lco.integrity = 'ALL' then
    perform datalink.dl_file_unlink(dlurlpathonly($1));
  end if; -- integrity all
 end if; -- link options
 
 return $1;
end$_$;

---------------------------------------------------

CREATE FUNCTION dl_trigger_table() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_X$
declare
  r record;
  ro jsonb;
  rn jsonb;
  link1 pg_catalog.datalink;
  link2 pg_catalog.datalink;
  opt datalink.link_control_options;
begin
  if tg_op = 'TRUNCATE' then
    perform datalink.dl_file_unlink(path)
       from datalink.dl_linked_files
      where attrelid = tg_relid; 
    return new;
  end if;

  if tg_op in ('DELETE','UPDATE') then ro := row_to_json(old)::jsonb; end if;  
  if tg_op in ('INSERT','UPDATE') then rn := row_to_json(new)::jsonb; end if;

  -- unlink old values
  for r in
  select column_name,lco 
    from datalink.dl_columns 
   where regclass = tg_relid
  loop
   link1 := null; link2 := null;
   if tg_op in ('DELETE','UPDATE') then link1 := ro->>r.column_name; end if;
   if tg_op in ('INSERT','UPDATE') then link2 := rn->>r.column_name; end if;
   if link1::jsonb->>'a' is distinct from link2::jsonb->>'a'
   or link1::jsonb->>'b' is distinct from link2::jsonb->>'b' then
    if tg_op in ('DELETE','UPDATE') then
       if dlurlcomplete(link1) is not null then
         link1 := datalink.dl_datalink_unref(link1,r.lco,tg_relid,r.column_name);
       end if;
    end if;
   end if;
  end loop; -- unlink old values

  -- link new values
  for r in
  select column_name,lco 
    from datalink.dl_columns 
   where regclass = tg_relid
  loop
   link1 := null; link2 := null;
   opt := datalink.link_control_options(r.lco);
   if tg_op in ('DELETE','UPDATE') then link1 := ro->>r.column_name; end if;
   if tg_op in ('INSERT','UPDATE') then link2 := rn->>r.column_name; end if;
   if link1::jsonb->>'a' is distinct from link2::jsonb->>'a'
   or link1::jsonb->>'b' is distinct from link2::jsonb->>'b' then
    if tg_op in ('INSERT','UPDATE') then
      if dlurlcomplete(link2) is not null then
         -- check for construction per SQL standard
        if tg_op = 'INSERT' then
          if link2::jsonb->>'k' in ('n','p') then
             raise exception 'DATALINK EXCEPTION - invalid datalink construction' 
                       using errcode = 'HW005',
                              detail =  'DLPREVIOUSCOPY and DLNEWCOPY are not permitted in INSERT';
          end if; -- if construction
        end if; -- if insert
        if tg_op = 'UPDATE' then
          if link2::jsonb->>'k' is not null then
            -- check for write_access = BLOCKED and prevent updates
            if opt.write_access = 'BLOCKED' and link1 is not null then
              raise exception 'DATALINK EXCEPTION - invalid write permission for update' using
                      errcode = 'HW006',
                       detail = format('write access is BLOCKED for column %s.%I',
                                       tg_relid::regclass::text,r.column_name),
                         hint = 'set write_access to ADMIN or TOKEN';
            end if; -- blocked
          -- check for write_access = TOKEN and prevent updates if needed
            if opt.write_access = 'TOKEN' and link1 is not null then
             if link2::jsonb->>'o' is null or link2::jsonb->>'o' is distinct from link1::jsonb->>'b' then
                raise exception 'DATALINK EXCEPTION - invalid write token' using 
                        errcode = 'HW004',
                         detail = format('New value doesn''t contain a matching write token for update of column %s.%I',
                                         tg_relid::regclass::text,r.column_name),
                           hint = 'Supply value with valid write token (DLNEWCOPY) or set write_access to ADMIN or TOKEN';
              end if; -- tokens not matching
            end if; -- token
            if link1::jsonb->>'a' is distinct from link2::jsonb->>'a' THEN
              raise exception 'DATALINK EXCEPTION - referenced file not valid' using
                      errcode = 'HW007',
                         detail = format('File address is different for for update of column %s.%I',
                                         tg_relid::regclass::text,r.column_name);
            end if;
          end if; -- construction 'k'
          if opt.write_access in ('ADMIN','TOKEN') then
            link2 := link2::jsonb - 'o';
          end if; 
--          link2 := link2::jsonb - 'k';
        end if; -- if update
   
        link2 := datalink.dl_datalink_ref(link2,r.lco,tg_relid,r.column_name);
        rn := jsonb_set(rn,array[r.column_name::text],to_jsonb(link2));
      end if; -- have URL
    end if; -- insert or update
   end if; -- distinct

  end loop; -- link new values

  if tg_op = 'DELETE' then return old; end if;
  new := jsonb_populate_record(new,rn);
  return new;   
end
$_X$;

---------------------------------------------------

CREATE FUNCTION dl_trigger_columns() RETURNS trigger
    LANGUAGE plpgsql
AS $$
declare
 my_lco datalink.dl_lco;
begin
 if tg_relid = 'datalink.columns'::regclass then
    my_lco := datalink.dl_lco(
      link_control=>cast(case new.integrity when 'NONE' then 'NO' else 'FILE' end as datalink.dl_link_control),
      integrity=>new.integrity,
      read_access=>new.read_access,write_access=>new.write_access,
      recovery=>new.recovery,
      on_unlink=>cast(case when new.write_access >= 'BLOCKED' then
                        case new.on_unlink
                        when 'NONE' then 'RESTORE'
                        else new.on_unlink
                        end
                      else 'NONE'
                      end as datalink.dl_on_unlink)
    );
    if new.integrity is not distinct from old.integrity then
      if new.link_control is distinct from old.link_control then
        if new.link_control = 'NO' then my_lco := 0; end if;
--        if new.link_control = 'FILE' then my_lco := 1; end if;
      end if; -- link control changed
    end if; -- integrity not changed
    perform datalink.modlco(regclass(old.table_name),old.column_name,my_lco);
    return new;
 end if; -- if datalink.columns
 if tg_relid = 'datalink.dl_columns'::regclass then
    my_lco := new.lco;
    perform datalink.modlco(old.regclass,old.column_name,my_lco);
    return new;
 end if; -- if datalink.dl_columns
 return new;
end
$$;

CREATE TRIGGER "columns_instead"
INSTEAD OF UPDATE ON datalink.columns
FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_columns();

CREATE TRIGGER "columns_instead"
INSTEAD OF UPDATE ON datalink.dl_columns
FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_columns();

---------------------------------------------------
-- curl functions
---------------------------------------------------

CREATE FUNCTION curl_get(
  INOUT url text, head integer DEFAULT 0, 
  OUT ok boolean, OUT rc integer, OUT body text, OUT error text, OUT size bigint, OUT elapsed float) 
RETURNS record
LANGUAGE plperlu
AS $_$
my ($url,$head)=@_;
my %r;
my $fs;

use strict;
use warnings;
use WWW::Curl::Easy;
use Time::HiRes qw(gettimeofday tv_interval);
use JSON;

# Starts and times the actual request
my $t0 = [gettimeofday];

# Check if this is a file on a foreign server and pass on the request
if($url=~m|^file://[^/]|i) {
  # then execute curl_get on that foreign server instead
  my $q=q{
    select pg_catalog.dlurlserver($1) as srvname,
    (select s.oid as srvoid from pg_catalog.pg_foreign_server s 
       join pg_catalog.pg_foreign_data_wrapper pfdw on (s.srvfdw=pfdw.oid)
      where srvname = pg_catalog.dlurlserver($1) and pfdw.fdwname = 'postgres_fdw'),
    (select extnamespace::regnamespace from pg_catalog.pg_extension where extname = 'dblink')
  };
  my $p = spi_prepare($q,'TEXT');
  $fs = spi_exec_prepared($p,$url)->{rows}->[0];
  unless($fs->{extnamespace}) {
    elog(ERROR,"DATALINK EXCEPTION - Extension dblink is required for files on foreign servers.\n");
  }
  unless($fs->{srvoid}) {
    elog(ERROR,"DATALINK EXCEPTION - Foreign server ".quote_ident($fs->{srvname})." does not exist.\n");
  }
  my $u = $url; $u=~s|^(file://)([^/]+)/|$1/|i; # clear server
  $q='select ok,rc,body,error from datalink.curl_get('.quote_nullable($u).','.quote_nullable($head).')';
  $p = spi_prepare('select ok,rc,body,error from '.quote_ident($fs->{extnamespace}).
                   '.dblink($1,$2) as dl(ok bool, rc int, body text, error text)',
                   'TEXT','TEXT');
  my $v = spi_exec_prepared($p,$fs->{srvname},$q);
  my $r = $v->{rows}->[0];
  $r->{url}=$url;
  $r->{elapsed} = tv_interval ( $t0, [gettimeofday] );
  return $r;
}

# $head = ($head eq't')?1:0;

my $curl = WWW::Curl::Easy->new;
$r{url} = $url;  
$curl->setopt(CURLOPT_USERAGENT,
              "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1");
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_HEADER,$head?1:0);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
#$curl->setopt(CURLOPT_RANGE, '100-200');
if($head) { $curl->setopt(CURLOPT_TIMEOUT, 5); }

# A filehandle, reference to a scalar or reference to a typeglob can be used here.
my $response_header;
my $response_body;
if($head) { $curl->setopt(CURLOPT_WRITEHEADER,\$response_header); }
else      { $curl->setopt(CURLOPT_WRITEDATA,\$response_body); }

my $retcode = $curl->perform;
$r{elapsed} = tv_interval ( $t0, [gettimeofday] );

# Looking at the results...
$r{ok} = ($retcode==0)?'yes':'no';
$r{rc} = $retcode;
if(!$r{rc}) { $r{rc} = $curl->getinfo(CURLINFO_HTTP_CODE); }
if($head) { $r{body} = $response_header; }
else      { $r{body} = $response_body; }
if(defined($r{body})) { utf8::decode($r{body}); }
if(!($retcode==0)) { $r{error} = $curl->strerror($retcode); }
if($head) { $r{size} = $curl->getinfo(CURLINFO_CONTENT_LENGTH_DOWNLOAD); }
else      { $r{size} = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD); }

return \%r;
$_$;
revoke execute on function curl_get(text,integer) from public;
comment on function curl_get(text,integer)
     is 'Access URLs with CURL. CURL groks URLs.';

---------------------------------------------------

CREATE FUNCTION curl_save(
  INOUT file_path file_path, INOUT url text, IN persistent int default 0,
  OUT ok boolean, OUT rc integer, OUT error text, OUT size bigint, OUT elapsed float) 
RETURNS record
LANGUAGE plperlu
AS $_$
my ($filename,$url,$persistent)=@_;

use strict;
use warnings;
use WWW::Curl::Easy;
use JSON;

if(!$filename) {
    elog(ERROR,"DATALINK EXCEPTION - Filename is NULL\n");
}

# Check if this is a file on a foreign server and pass on the request
if($url=~m|^file://[^/]|i) {
    elog(ERROR,"DATALINK EXCEPTION - Foreign servers not supported in curl_save\nURL: $url");
}

my %r;
my $fh;
my $op = ($persistent>0)?'w':'t';

my $q = q{select user, datalink.has_file_privilege($1,$2,true) as ok};
my $p = spi_prepare($q,'datalink.file_path','text');
my $fs = spi_exec_prepared($p,$filename,'create')->{rows}->[0];
unless($fs->{ok} eq 't') { 
    die qq{DATALINK EXCEPTION - CREATE permission denied on directory}.
        qq{ for role "$fs->{user}".\nFILE: $filename\n}; 
}
if(-e $filename) { die "DATALINK EXCEPTIION - File exists\nFILE: $filename\n"; }

$p = spi_prepare(q{select datalink.dl_file_admin($1,$2)},'datalink.file_path','"char"');
unless(spi_exec_prepared($p,$filename,$op)) { die "DATALINK EXCEPTION - dl_file_admin() failed"; }

my $curl = WWW::Curl::Easy->new;
$r{url} = $url;  
$curl->setopt(CURLOPT_USERAGENT,
              "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1");
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_HEADER,0);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);

open($fh,">",$filename) or die "DATALINK EXCEPTION - Cannot open file for writing: $!\nFILE: $filename\n";
# A filehandle, reference to a scalar or reference to a typeglob can be used here.
$curl->setopt(CURLOPT_WRITEDATA,$fh);

my $retcode = $curl->perform;
close $fh;

# Looking at the results...
$r{ok} = ($retcode==0)?'yes':'no';
$r{rc} = $retcode;
if(!$r{rc}) { 
  $r{rc} = $curl->getinfo(CURLINFO_HTTP_CODE);
  if(!($r{rc} ==  0 || ( $r{rc} >= 200 && $r{rc} <= 299 ))) { $r{ok} = 'no'; }
}
$r{file_path} = $filename;
#$r{size} = $curl->getinfo(CURLINFO_CONTENT_LENGTH_DOWNLOAD);
$r{size} = $curl->getinfo(CURLINFO_SIZE_DOWNLOAD);
$r{elapsed} = $curl->getinfo(CURLINFO_TOTAL_TIME);
if(!($retcode==0)) { $r{error} = $curl->strerror($retcode); }
if($r{ok} eq 'no') { unlink($filename); }

return \%r;
$_$;
revoke execute on function curl_save(file_path,text,int) from public;
comment on function curl_save(file_path,text,int)
     is 'Save content of remote URL to a local file';

---------------------------------------------------
-- admin functions
---------------------------------------------------

CREATE FUNCTION modlco(
  my_regclass regclass,
  my_column_name name, 
  new_lco dl_lco)
RETURNS link_control_options
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $_$
declare
 co record;
 obj record;
 e text;
 n bigint;
 old_options datalink.link_control_options;
 new_options datalink.link_control_options;
 complicated boolean;
begin
 select into co * from datalink.dl_columns
  where regclass = my_regclass and column_name = my_column_name; 

 if not found then
      raise exception 'DATALINK EXCEPTION' 
            using errcode = 'HW000',
            detail = 'Not a DATALINK column';
 end if; 

 if not datalink.has_class_privilege(my_regclass) then
      raise exception 'DATALINK EXCEPTION' 
            using errcode = 'HW000',
            detail = format('Must be owner of class '%s' to change link control options',my_regclass);
 end if;

 select * into old_options from datalink.link_control_options where lco = co.lco;
 select * into new_options from datalink.link_control_options where lco = new_lco;

 if not found then
      raise exception 'DATALINK EXCEPTION' 
            using errcode = 'HW000',
                  detail = format('Invalid link control options (%s)',new_lco),
                  hint = 'see table datalink.link_control_options for valid link control options';
 end if; 

 if new_lco is distinct from co.lco then
   complicated := (old_options.integrity is distinct from new_options.integrity)
               or (old_options.read_access='FS' and new_options.read_access>'FS')
               or (old_options.read_access>'FS' and new_options.read_access='FS')
               or (old_options.write_access='FS' and new_options.write_access>'FS')
               or (old_options.write_access>'FS' and new_options.write_access='FS')
               or (old_options.recovery='NO' and new_options.recovery='YES');
   if complicated then
    e := format('select count(%I) from %s where %I is not null limit 1',
      my_column_name,cast(my_regclass as text),my_column_name);
    execute e into n;
    if n > 0 then
        raise exception 'DATALINK EXCEPTION' 
              using errcode = 'HW000',
              detail = format('Can''t change link control options; %s non-null values present in column "%s"',
                        n,my_column_name),
                    hint = format('Perhaps you can "truncate %s"',my_regclass);
    end if; -- values present
   end if; -- complicated

   -- update column options with new lco
   update pg_attribute 
      set -- attfdwoptions=array['dl_lco='||my_lco],
          atttypmod=case when new_lco > 0 then new_lco+4 else -1 end
    where attrelid=my_regclass and attname=my_column_name;

   -- update linked files
   update datalink.dl_linked_files
      set lco = new_lco
    where attrelid = my_regclass and attnum = co.attnum;

   -- update triggers
   for obj in select * from datalink.dl_trigger_advice()
   where not valid and regclass = my_regclass
   loop
     RAISE NOTICE 'DATALINK DDL:% on %','TRIGGER',obj.regclass;
     execute obj.sql_advice;
   end loop;

end if; -- lco has changed

 return new_options;
end;
$_$;

COMMENT ON FUNCTION modlco(my_regclass regclass, my_column_name name, my_lco dl_lco) 
IS 'Modify link control options for a datalink column';

---------------------------------------------------
-- SQL/MED functions
---------------------------------------------------

CREATE FUNCTION pg_catalog.dlcomment(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $$ select $1::jsonb->>'c' $$;
COMMENT ON FUNCTION pg_catalog.dlcomment(datalink) 
IS 'SQL/MED - Returns the comment value, if it exists, from a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcomplete(datalink, anonymous integer default 0) RETURNS text
    LANGUAGE sql STRICT stable
AS $_$ 
   select case 
          when $1::jsonb->>'b' is not null 
           and (datalink.link_control_options($1)).read_access = 'DB'
          then datalink.dl_url_insight(pg_catalog.dlurlcompleteonly($1)
                                   ,($1::jsonb->>'b')::datalink.dl_token,anonymous)
          else format('%s%s',pg_catalog.dlurlcompleteonly($1),'#'||datalink.uri_get($1::jsonb->>'a','fragment'))
          end
$_$;
COMMENT ON FUNCTION pg_catalog.dlurlcomplete(datalink, integer) 
IS 'SQL/MED - Returns the data location attribute (URL) from a DATALINK value';

CREATE FUNCTION pg_catalog.dlurlcomplete(text, integer default 0) RETURNS text LANGUAGE sql STRICT stable
AS $_$ select pg_catalog.dlurlcomplete(dlvalue($1),$2) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlcomplete(text, integer) 
IS 'SQL/MED - Returns normalized URL value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcompleteonly(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select datalink.uri_get(
  case when datalink.is_local($1)
       then coalesce((
               select dirurl||uri_escape(substr(pg_catalog.dlurlpathonly($1),length(dirpath)+1))
                 from datalink.directory
                where dirurl is not null
                  and pg_catalog.dlurlpathonly($1) like dirpath||'%'
                order by length(dirpath) desc limit 1
            ),$1::jsonb->>'a')
       else $1::jsonb->>'a'
  end,'only')
$_$;
COMMENT ON FUNCTION pg_catalog.dlurlcompleteonly(datalink) 
IS 'SQL/MED - Returns the data location attribute (URL) from a DATALINK value';

CREATE FUNCTION pg_catalog.dlurlcompleteonly(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlcompleteonly(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlcompleteonly(text) 
IS 'SQL/MED - Returns normalized URL value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlserver(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select nullif(datalink.uri_get($1::jsonb->>'a','host'),'')$function$;
COMMENT ON FUNCTION pg_catalog.dlurlserver(datalink)
     IS 'SQL/MED - Returns the file server from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlserver(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlserver(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlserver(text) 
IS 'SQL/MED - Returns the file server from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlscheme(datalink)
RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select upper(datalink.uri_get($1::jsonb->>'a','scheme'))$function$;

COMMENT ON FUNCTION pg_catalog.dlurlscheme(datalink)
     IS 'SQL/MED - Returns the scheme from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlscheme(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlscheme(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlscheme(text) 
IS 'SQL/MED - Returns the scheme from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlpath(datalink, anonymous integer default 0)
 RETURNS text
  LANGUAGE sql
   STRICT
   AS $function$
   select case 
          when datalink.is_local($1) and $1::jsonb->>'b' is not null 
           and (datalink.link_control_options($1)).read_access = 'DB'
          then datalink.uri_get(
            datalink.dl_url_insight($1::jsonb->>'a',($1::jsonb->>'b')::datalink.dl_token,anonymous),'path')
          else coalesce(datalink.filepath($1),
                  format('%s%s',datalink.uri_get($1::jsonb->>'a','path'),
                        '#'||coalesce($1::jsonb->>'b',datalink.uri_get($1::jsonb->>'a','token'))))
          end
$function$;

COMMENT ON FUNCTION pg_catalog.dlurlpath(datalink, integer)
     IS 'SQL/MED - Returns the file path from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlpath(text, anonymous integer default 0) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlpath(dlvalue($1),$2) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlpath(text, integer) 
IS 'SQL/MED - Returns the file path from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlpathwrite(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$
   select format('%s%s',
                  datalink.uri_get($1::jsonb->>'a','path'),
                  '#'||coalesce($1::jsonb->>'b',datalink.uri_get($1::jsonb->>'a','token'))
          )
$function$;

COMMENT ON FUNCTION pg_catalog.dlurlpathwrite(datalink)
     IS 'SQL/MED - Returns the write file path from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlpathwrite(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlpathwrite(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlpathwrite(text) 
IS 'SQL/MED - Returns the write file path from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlpathonly(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select datalink.uri_get($1::jsonb->>'a','path')$function$;

COMMENT ON FUNCTION pg_catalog.dlurlpathonly(datalink)
     IS 'SQL/MED - Returns the file path from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlpathonly(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlpathonly(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlpathonly(text) 
IS 'SQL/MED - Returns the file path from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dllinktype(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $$ select coalesce($1::jsonb->>'t',case when datalink.is_local($1) then 'FS' else 'URL' end )$$;

COMMENT ON FUNCTION pg_catalog.dllinktype(datalink)
     IS 'SQL/MED - Returns the link type (URL, FS or custom) of DATALINK value';

CREATE FUNCTION pg_catalog.dllinktype(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dllinktype(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dllinktype(text) 
IS 'SQL/MED - Returns the link type (URL or FS) from URL';

---------------------------------------------------

create or replace function pg_catalog.dlreplacecontent(link datalink, new_content datalink) returns datalink
language plpgsql strict as $$
DECLARE
  loid oid;
  path datalink.file_path;
  url text;
  r record;
BEGIN
  link := dlnewcopy(link);
  path := dlurlpathwrite(link);
  url := dlurlcompleteonly(new_content);

  r := datalink.curl_save(path,url);
  if not r.ok then
    raise exception e'DATALINK EXCEPTIION - Failed to copy resource\nURL: %',url
    using errcode = 'HW303',
          detail = format('CURL error %s - %s',r.rc,r.error),
          hint = 'make sure URL is correct and referenced file actually exists';
  end if;
  link := jsonb_set(link::jsonb,'{k}',to_jsonb('r'::text));
  return link;
end
$$;
COMMENT ON FUNCTION pg_catalog.dlreplacecontent(datalink, datalink) 
IS 'SQL/MED - Replace contents of a DATALINK with contents of another DATALINK';

create or replace function pg_catalog.dlreplacecontent(link datalink, new_content text) returns datalink
language sql as $$ select pg_catalog.dlreplacecontent($1,dlvalue($2)) $$;
COMMENT ON FUNCTION pg_catalog.dlreplacecontent(datalink, text) 
IS 'SQL/MED - Replace contents of a DATALINK with contents of another DATALINK';

create or replace function pg_catalog.dlreplacecontent(link text, new_content datalink) returns datalink
language sql as $$ select pg_catalog.dlreplacecontent(dlvalue($1),$2) $$;
COMMENT ON FUNCTION pg_catalog.dlreplacecontent(text, datalink) 
IS 'SQL/MED - Replace contents of a DATALINK with contents of another DATALINK';

create or replace function pg_catalog.dlreplacecontent(link text, new_content text) returns datalink
language sql as $$ select pg_catalog.dlreplacecontent(dlvalue($1),dlvalue($2)) $$;
COMMENT ON FUNCTION pg_catalog.dlreplacecontent(text, text) 
IS 'SQL/MED - Replace contents of a DATALINK with contents of another DATALINK';

---------------------------------------------------
alter domain url add check (datalink.uri_get(value,'scheme') is not null);
-- alter domain url add check (value ~* '^(https?|s?ftp|file):///?[^\s/$.?#].[^\s]*$');

create function dl_url(datalink) returns uri 
  language sql strict immutable 
as $$select dlurlcomplete($1)::uri$$;

create cast (datalink as uri) with function datalink.dl_url;

---------------------------------------------------

CREATE SERVER IF NOT EXISTS datalink_file_server FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE dl_prfx (
  prefix text NULL
)
SERVER datalink_file_server
OPTIONS (filename '/etc/postgresql-common/pg_datalinker.prefix');

CREATE FUNCTION has_valid_prefix(file_path)
 RETURNS boolean LANGUAGE sql STABLE STRICT
AS $function$
select exists (
 select prefix from datalink.dl_prfx
  where $1 like prefix||'%'
)
$function$
;
COMMENT ON FUNCTION has_valid_prefix(datalink.file_path)
     IS 'Is file path prefixed with a valid prefix?';

---------------------------------------------------
create or replace function dl_authorize(
  file_path, for_web integer default 1, myrole regrole default user::regrole) 
returns file_path
language plpgsql security definer
as $$
declare
  mypath text;
  t text;
  f record;
  m text[];
begin
 -- check for read token
 m := regexp_matches($1,'^(.*/)(([a-z0-9\-]{36});)?(.*)$','i');
 mypath := coalesce(m[1]||m[4],$1);
 t := m[3]::datalink.dl_token;
 -- check access
 select token,read_access
   from datalink.dl_linked_files
   join datalink.link_control_options lco using(lco)
  where path=mypath
   into f;
 if f.read_access = 'DB' then
  if f.token::text = t then return mypath; end if;
  update datalink.insight
     set atimes=atimes||array[now()], 
         grantees=grantees||array[myrole],
         pids=pids||array[pg_backend_pid()]
   where read_token=t::datalink.dl_token 
     and link_token=f.token;
  if found then return mypath; end if;
  if for_web>0 then return null; end if;
 end if;
 mypath := $1;
 if for_web>0 then return mypath;
 else 
  if datalink.has_file_privilege(myrole,mypath,'SELECT',true) then return mypath; end if;
  raise exception e'DATALINK EXCEPTION - SELECT permission denied on directory for role "%".\nFILE:  %\n',myrole,mypath 
  using errcode = 'HW007',
        detail  = format('no SELECT permission for directory'),
        hint    = format('add SELECT privilege for role %s to table DATALINK.ACCESS',myrole);
 end if;
 return null;
end$$;
comment on function dl_authorize(file_path, integer, regrole)
     is 'Authorize access to READ ACCESS DB file via embedded read token';

---------------------------------------------------
CREATE FUNCTION read_text(datalink, pos bigint default 1, len bigint default null)
 RETURNS text LANGUAGE plpgsql
AS $$
begin
  if datalink.is_local($1) then
    return datalink.read_text(dlurlpath($1),$2,$3);
  end if;
  return case
         when $2 > 1 or $3 is not null
         then substr((datalink.curl_get(dlurlcomplete($1))).body,$2::integer,$3::integer)
         else (datalink.curl_get(dlurlcomplete($1))).body end;
end
$$;
COMMENT ON FUNCTION read_text(datalink,bigint,bigint) IS 
  'Read datalink contents as text';

CREATE OR REPLACE FUNCTION read_text(filename file_path, pos bigint default 1, len bigint default null)
 RETURNS text
 LANGUAGE plperlu AS $$
  use strict vars; 
  my ($filename,$pos,$len)=@_;

  my $q=q{select datalink.dl_authorize($1,0) as path};
  my $p = spi_prepare($q,'datalink.file_path');
  my $fs = spi_exec_prepared($p,$filename)->{rows}->[0];
  if(defined($fs->{path})) { $filename=$fs->{path}; }

  open my $fh, $filename or die "DATALINK EXCEPTION - Can't open $filename: $!\n";
  if($pos>1) { seek($fh,$pos-1,0); }
  my $i=1; my $o=$pos; my $bufr;
  if(defined($len)) { read $fh,$bufr,$len; } 
  else { local $/; $bufr = <$fh>; }
  close $fh;
  if(defined($bufr)) { utf8::decode($bufr); }
  return $bufr;
$$;
COMMENT ON FUNCTION read_text(file_path,bigint,bigint) IS 
  'Read local file contents as text';

---------------------------------------------------
CREATE OR REPLACE FUNCTION read_lines(filename file_path, pos bigint default 1)
 RETURNS TABLE(i integer, o bigint, line text)
 LANGUAGE plperlu STRICT AS $$
  use strict vars; 
  my ($filename,$pos)=@_;

  my $q=q{select datalink.dl_authorize($1,0) as path};
  my $p = spi_prepare($q,'datalink.file_path');
  my $fs = spi_exec_prepared($p,$filename)->{rows}->[0];
  if(defined($fs->{path})) { $filename=$fs->{path}; }

  open my $fh, $filename or die "DATALINK EXCEPTION - Can't open $filename: $!";
  if($pos>1) { seek($fh,$pos-1,0); }
  my $i=1; my $o=$pos;
  while(my $line = <$fh>) {
    chop($line);
    if(defined($line)) { utf8::decode($line); }
    return_next {i=>$i,o=>$o,line=>$line};
    $i++; $o+=length($line)+1;
  }
  close $fh;
  return undef;
$$;
COMMENT ON FUNCTION read_lines(file_path,bigint)
     IS 'Stream local file as lines of text';

CREATE OR REPLACE FUNCTION read_lines(link datalink, pos bigint default 1)
 RETURNS TABLE(i integer, o bigint, line text)
 LANGUAGE sql STRICT AS $$ 
select * from datalink.read_lines(dlurlpath($1),pos)
$$;
COMMENT ON FUNCTION read_lines(datalink, bigint)
     IS 'Stream local file referenced by a datalink as lines of text';

---------------------------------------------------

CREATE OR REPLACE FUNCTION write_text(filename file_path, content text, persistent integer default 0)
 RETURNS text
 LANGUAGE plperlu
AS $function$
  use strict vars; 
  my ($filename,$bufr,$persistent)=@_;
  my $fh;
  my $op = ($persistent>0)?'w':'t';

  my $q = q{select datalink.has_file_privilege($1,$2,true) as ok, user};
  my $p = spi_prepare($q,'datalink.file_path','text');
  my $fs = spi_exec_prepared($p,$filename,'create')->{rows}->[0];
  unless($fs->{ok} eq 't') { 
    die qq{DATALINK EXCEPTION - CREATE permission denied on directory}.
        qq{ for role "$fs->{user}".\nFILE: $filename\n}; 
  }

  if(-e $filename) { die "DATALINK EXCEPTIION - File exists\nFILE: $filename\n"; }

  $p = spi_prepare(q{select datalink.dl_file_admin($1,$2)},'datalink.file_path','"char"');
  unless(spi_exec_prepared($p,$filename,$op)) { die "DATALINK EXCEPTION - dl_file_admin() failed"; }

  open($fh,">",$filename) or die "DATALINK EXCEPTION - Cannot open file for writing: $!\nFILE: $filename\n";
  if(defined($bufr)) { utf8::encode($bufr); }
  print $fh $bufr;
  close $fh;
  return $filename;
$function$;
COMMENT ON FUNCTION write_text(file_path,text,integer) IS 
  'Write new local file contents as text';

---------------------------------------------------

CREATE OR REPLACE FUNCTION write_text(link datalink, content text, persistent integer default 0)
 RETURNS datalink
 LANGUAGE plpgsql
AS $function$
begin
 if not datalink.is_local(link) THEN
    raise exception 'DATALINK EXCEPTION - invalid datalink construction' 
              using errcode = 'HW005',
                    detail = 'write_text can only be used with local file URLs',
                    hint = 'make sure you are using a file: URL scheme';
 end if;
 link := dlnewcopy(link);
 perform datalink.write_text(dlurlpathwrite(link),content,persistent);
 return link;
end
$function$;
COMMENT ON FUNCTION write_text(datalink,text,integer) IS 
  'Write datalink contents as text';

---------------------------------------------------
-- bfile compatibility functions
---------------------------------------------------

create or replace function fileexists(datalink) returns integer as $$
select case 
       when datalink.is_local($1)
       then datalink.filepath($1) is not null
       else (datalink.curl_get(dlurlcomplete($1),1)).rc between 200 and 299
       end :: integer
$$ language sql;
comment on function fileexists(datalink) is 
  'BFILE - Returns whether datalink file exists';
create or replace function fileexists(file_path) returns integer as $$
select datalink.fileexists(dlvalue($1,'FS'))
$$ language sql;
comment on function fileexists(file_path) is 
  'BFILE - Returns whether file exists';

create or replace function filegetname(datalink, OUT dirname text, OUT filename text, OUT dirpath text)
returns record as $$
  select dirname, substr(dlurlpathonly($1),length(dirpath)+1), dirpath
    from datalink.directory 
   where dlurlpathonly($1) like dirpath||'%'
   order by length(dirpath) desc
   limit 1
$$ strict language sql;
comment on function filegetname(datalink) is 
  'BFILE - Returns directory name and filename for a datalink';
create or replace function filegetname(file_path, OUT dirname text, OUT filename text, OUT dirpath text)
returns record as $$ select * from datalink.filegetname(dlvalue($1,'FS') $$ strict language sql;
comment on function filegetname(file_path) is 
  'BFILE - Returns directory name and filename for a file';

create or replace function getlength(datalink) returns bigint as 
$$ select (datalink.stat(datalink.filepath($1))).size::bigint $$ language sql;
comment on function getlength(datalink) is 
  'BFILE - Returns datalink file size';
create or replace function getlength(file_path) returns bigint as 
$$ select datalink.getlength(dlvalue($1,'FS')) $$ language sql;
comment on function getlength(file_path) is 
  'BFILE - Returns file size';

create or replace function pg_catalog.substr(datalink, pos integer default 1, len integer default 32767) returns text as 
$$ select datalink.read_text($1,$2,$3) $$ language sql;


create or replace function substr(datalink, pos integer default 1, len integer default 32767) returns text as 
$$ select datalink.read_text($1,$2,$3) $$ language sql;
comment on function substr(datalink, integer, integer) is 
  'BFILE - Returns part of the datalink file starting at the specified offset and length';
create or replace function substr(file_path, pos integer default 1, len integer default 32767) returns text as 
$$ select datalink.read_text($1,$2,$3) $$ language sql;
comment on function substr(file_path, integer, integer) is 
  'BFILE - Returns part of the file starting at the specified offset and length';

create or replace function instr(datalink, pattern text, pos integer default 1) returns integer as 
$$ select position($2 in datalink.read_text($1,$3::bigint)) $$ language sql;
comment on function instr(datalink,text, integer) is 
  'BFILE - Returns the matching position of a pattern in a datalink file';
create or replace function instr(file_path, pattern text, pos integer default 1) returns integer as 
$$ select position($2 in datalink.read_text($1,$3::bigint)) $$ language sql;
comment on function instr(file_path,text, integer) is 
  'BFILE - Returns the matching position of a pattern in a file';

---------------------------------------------------
-- directories
---------------------------------------------------
create table dl_directory (
       dirname    text collate "C" unique check(dirname not in ('URL','FS')),
       dirpath    file_path not null check(dirpath like '/%/'),
       dirowner   regrole,
       diracl     aclitem[],
       dirlco     dl_lco,
       dirurl     uri unique,
       diroptions text[] collate "C",
       dirlink    datalink(2) not null
);

create view directory as
select coalesce(dirpath,prefix) as dirpath,
       dirname,        
       dirowner,
       diracl,
       dirlco,
       dirurl,
       diroptions
  from dl_prfx dp
  left join dl_directory dir on (dir.dirpath like dp.prefix||'%')
;
COMMENT ON VIEW directory 
     IS 'Configured datalink file system directories';
GRANT SELECT ON datalink.directory TO PUBLIC;

CREATE FUNCTION dl_trigger_directory() RETURNS trigger
    LANGUAGE plpgsql
AS $$
declare
begin
  if tg_relid = 'datalink.directory'::regclass then
    update datalink.dl_directory
       set (dirname,dirowner,diracl,dirlco,dirurl,diroptions) =
          (new.dirname,new.dirowner,new.diracl,new.dirlco,new.dirurl,new.diroptions)
     where dirpath = new.dirpath;
    if not found then
      insert into datalink.dl_directory (dirname,dirpath,dirowner,diracl,dirlco,dirurl,diroptions)
      values (new.dirname,new.dirpath,new.dirowner,new.diracl,new.dirlco,new.dirurl,new.diroptions);
    end if;
  end if;  -- if datalink.directory
  if tg_relid = 'datalink.dl_directory'::regclass then
    new.dirpath := trim(trailing '/' from new.dirpath) || '/';
    if not datalink.has_valid_prefix(new.dirpath) then 
        raise exception 'DATALINK EXCEPTION - referenced file not valid' 
              using errcode = 'HW007',
                    detail = format('unknown path prefix for %s',new.dirpath),
                    hint = 'run "dlfm add" to add prefixes';
    end if;

  if tg_op = 'INSERT' or 
     (tg_op = 'UPDATE' and dlurlpathonly(old.dirlink) is distinct from new.dirpath) then
    new.dirlink := dlvalue(new.dirpath,'FS');
  end if; -- must update datalink

 end if;  -- if datalink.dl_directory
 return new;
end
$$;

CREATE TRIGGER "dl_directory_touch"
BEFORE INSERT OR UPDATE ON datalink.dl_directory FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_directory();

CREATE TRIGGER "directory_touch"
INSTEAD OF UPDATE OR INSERT ON datalink.directory FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_directory();

create or replace function filegetdirectory(file_path)
returns directory as $$
  select * from datalink.directory 
   where $1 like dirpath||'%'
   order by length(dirpath) desc limit 1
$$ strict language sql;

---------------------------------------------------
-- access permitions
---------------------------------------------------

CREATE OR REPLACE VIEW access
AS SELECT d.dirpath,
    e.privilege_type,
        CASE e.grantee
            WHEN 0 THEN 'PUBLIC'::text
            ELSE e.grantee::regrole::text
        END AS grantee,
        CASE e.grantor
            WHEN 0 THEN 'PUBLIC'::text
            ELSE e.grantor::regrole::text
        END AS grantor,
    e.is_grantable
   FROM datalink.directory d
     JOIN LATERAL aclexplode(nullif(d.diracl,'{}')) e(grantor, grantee, privilege_type, is_grantable) ON true;

COMMENT ON VIEW access 
     IS 'Permissions for file system directories';
GRANT SELECT ON access TO PUBLIC;

CREATE FUNCTION dl_trigger_access() RETURNS trigger
    LANGUAGE plpgsql
AS $$
declare
  dir text;
  acl aclitem;
  acls aclitem[];
BEGIN
  if tg_op in ('UPDATE','DELETE') 
    then dir := old.dirpath;
    else dir := new.dirpath; 
  end if;

  select diracl from datalink.directory where dirpath = dir into acls;
  if not found THEN
    raise exception e'DATALINK EXCEPTION - directory not found\nPATH:  %',dir 
          using errcode = 'HW003', 
                detail = 'directory not found while modifying datalink.access',
                hint = 'add appropriate entry in table datalink.directory';
  end if;
  if tg_op in ('UPDATE','DELETE') THEN
    acl := makeaclitem(coalesce(coalesce(nullif(lower(old.grantee),'public'),'0'), old.grantee)::regrole,
                       coalesce(old.grantor::regrole,current_role::regrole),
                       upper(old.privilege_type),coalesce(old.is_grantable,false)); 
    acls := array_remove(acls,acl);
  end if; -- update or delete
  if tg_op in ('INSERT','UPDATE') THEN
    acl := makeaclitem(coalesce(coalesce(nullif(lower(new.grantee),'public'),'0'), new.grantee)::regrole,
                       coalesce(new.grantor::regrole,current_role::regrole),
                       upper(new.privilege_type),coalesce(new.is_grantable,false)); 
    acls := case 
            when acls = '{}' then array[acl]
            when acls @> acl then acls
            else coalesce(acls,'{}'::aclitem[]) || array[acl] end;
  end if; -- insert or update
     update datalink.directory
        set diracl = acls
      where dirpath = dir; 
  if tg_op = 'DELETE' then return old; end if;
  return new;
END
$$;

CREATE TRIGGER "access_touch"
INSTEAD OF UPDATE OR INSERT OR DELETE ON datalink.access FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_access();

---------------------------------------------------
-- inquire access permitions
---------------------------------------------------

CREATE OR REPLACE FUNCTION has_file_privilege(role regrole,file_path datalink.file_path,privilege text, allowsuper boolean default true) RETURNS boolean as $$
select (current_setting('is_superuser')::boolean and $4) or exists (
  select dirpath from datalink.access 
   where privilege_type=upper($3)
     and dirpath = (datalink.filegetdirectory ($2)).dirpath
     and (grantee = 'PUBLIC' or grantee = $1::text)
)
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION has_file_privilege(file_path datalink.file_path, privilege text, allowsuper boolean default true) RETURNS boolean
 LANGUAGE sql AS $$select datalink.has_file_privilege(current_role::regrole,$1,$2,$3)$$;

---------------------------------------------------
-- datalinker status
---------------------------------------------------

CREATE TABLE dl_status (
  pid integer default pg_backend_pid(),
  cpid integer,
  version text,
  atime timestamptz,
  mtime timestamptz,
  links bigint default 0,
  unlinks bigint default 0
);
insert into dl_status (version) values ('init');
grant select on dl_status to public;

---------------------------------------------------
CREATE PROCEDURE commit() language plpgsql as $$
begin

  if not datalink.has_datalinker() then
        raise exception 'DATALINK ERROR - datalinker required' 
              using errcode = '57050',
              hint = 'make sure pg_datalinker process is running to finalize your commits';
  end if;

  notify "datalink.linker_jobs"; 
  commit;

  perform pg_advisory_lock(x'41444154494c4b4e'::bigint);
  perform pg_advisory_unlock(x'41444154494c4b4e'::bigint);

end
$$;
COMMENT ON PROCEDURE commit() 
     IS 'Wait for datalinker to apply changes';

---------------------------------------------------

CREATE FUNCTION has_datalinker()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
select exists (
 select usename
   from pg_stat_activity
   join datalink.dl_status using (pid)
  where datname = current_database() 
    and application_name='pg_datalinker'
)
$function$
;
COMMENT ON FUNCTION has_datalinker()
     IS 'Is datalinker process currently running?';

---------------------------------------------------
-- insight (file lookup) table
---------------------------------------------------

create table insight (
  link_token dl_token not null,
  read_token dl_token default datalink.dl_newtoken() primary key,
  ctime timestamptz not null default now(),
  grantor regrole not null default user::regrole,
  atimes timestamptz[],
  grantees regrole[],
  pids int[],
  data jsonb
);
alter table insight add foreign key (link_token) references 
  datalink.dl_linked_files(token) on update cascade on delete cascade;
create index insight_link_token_idx on insight (link_token);

CREATE FUNCTION dl_url_insight(url text, link_token dl_token, anonymous integer default 0) 
RETURNS text LANGUAGE plpgsql strict
AS $$
declare
  m text[];
begin
 -- check for read token
 m := regexp_matches(url,'^([^#]*/)(([a-z0-9\-]{36});)?(.*)$','i');
 if anonymous>0 then
  insert into datalink.insight (link_token) values (link_token) 
  returning read_token into link_token;
 end if;
 return coalesce(m[1]||link_token||';'||m[4],$1);
end
$$;

---------------------------------------------------
-- temporary files
---------------------------------------------------
-- administered (copied, moved, deleted) files
create table dl_admin_files (
  txid xid8 not null default pg_current_xact_id(),
  ctime timestamptz not null default now(),
  regrole regrole not null default current_role::regrole,
  path file_path primary key,
  token dl_token unique,
  op "char" not null,
  options jsonb
);

-- mark file as temporary to be deleted if the transaction aborts
create or replace function dl_file_admin(file_path, op "char", options jsonb default null) returns text
language plpgsql as $$
declare 
  my_txid xid8;
  dsn text;
  sql text;
  ns regnamespace;
begin 
  my_txid := pg_current_xact_id();
  sql := format('insert into datalink.dl_admin_files (op,path,txid,options) values (%L,%L,%L,%L) '||
                ' on conflict (path) do nothing',$2,$1,my_txid,$3);
  select extnamespace::regnamespace from pg_catalog.pg_extension where extname = 'dblink' into ns;
  if not found THEN
    raise warning 'DATALINK WARNING - dblink extension recommended' 
    using detail = 'Extension dblink is needed for automatic delete of files from aborted transactions',
          hint   = 'Install dblink extension';
    execute sql;
  else 
    dsn := format('dbname=%s port=%s',current_database(),current_setting('port'));
  --  perform dblink_exec(dsn,sql,true);
    execute format('select %I.dblink_exec(%L,%L,true)',ns,dsn,sql);
    notify "datalink.linker_jobs"; 
  end if;
  return $1;
end
$$;

---------------------------------------------------
-- list versions
---------------------------------------------------

create or replace function revisions(file_path) 
returns table(rev bigint,ctime timestamptz,link datalink)
strict LANGUAGE plpgsql as $$
DECLARE
  dirs text[];
   dir text;
BEGIN
  dirs := string_to_array($1,'/');
  dirs := dirs[1:cardinality(dirs)-1];
   dir := array_to_string(dirs,'/');
return query
  with ls as (select dir||'/'||filename as path from pg_ls_dir(dir) filename)
select -row_number() over(order by s.mtime desc),
       to_timestamp(s.mtime),
       dlpreviouscopy(dlvalue(path,'FS'),1)
  from ls, datalink.stat(path) s
 where path ~* '#[0-9a-z\-]{36}$'
   and path like $1||'%'
 order by s.mtime desc;
end
$$;
comment on function revisions(file_path)
is 'All available previous revisions of a file as datalinks';

create or replace function revisions(datalink) 
returns table(rev bigint,ctime timestamptz,link datalink)
strict LANGUAGE sql as $$
select rev,ctime,link
  from datalink.revisions(pg_catalog.dlurlpathonly($1))
$$;
comment on function revisions(datalink)
is 'All available previous revisions of a datalink';

create or replace function revision(datalink, revision int default -1) returns datalink 
language sql strict as $$
 select link from datalink.revisions($1) where rev = $2
$$;
comment on function revision(datalink,int)
is 'Return a particular datalink revision';


---------------------------------------------------
-- volume usage statistics
---------------------------------------------------

create or replace view usage as
WITH a AS (
         SELECT d.dirname AS dirname,
                d.filename AS filename,
                d.dirpath AS dirpath,
                (datalink.stat(linked_files.path)).size AS size,
                linked_files.path,
                linked_files.state,
                linked_files.read_access,
                linked_files.write_access,
                linked_files.recovery,
                linked_files.on_unlink,
                linked_files.regclass,
                linked_files.attname,
                linked_files.owner,
                linked_files.err
           FROM datalink.linked_files,
                datalink.filegetname(dlvalue(linked_files.path::text)) as d
        )
 SELECT a.dirpath,
    sum(a.size) FILTER (WHERE length(a.filename) > 0) AS size,
    sum(1) FILTER (WHERE length(a.filename) > 0) AS count,
    sum(case when a.state='LINKED' then 1 end) FILTER (WHERE length(a.filename) > 0) AS linked,
    sum(case when a.err is not null then 1 end) FILTER (WHERE length(a.filename) > 0) AS error,
    sum(case when a.state = ANY ('{LINK,UNLINK}'::file_link_state[]) then 1 end) FILTER (WHERE length(a.filename) > 0) AS waiting
   FROM a
  GROUP BY GROUPING SETS ((a.dirpath), ())
  ORDER BY a.dirpath;
COMMENT ON VIEW usage
     IS 'Disk directory usage statistics';
grant select on usage to public;

---------------------------------------------------
-- play tables
---------------------------------------------------

create table sample_datalinks ( link datalink(1) );
grant select on sample_datalinks to public;
comment on table sample_datalinks
     is 'Sample datalinks with selective integrity';

---------------------------------------------------
-- add stuff to pg_dump 
---------------------------------------------------
-- SELECT pg_catalog.pg_extension_config_dump('datalink.dl_linked_files', '');
SELECT pg_catalog.pg_extension_config_dump('datalink.sample_datalinks', '');
-- SELECT pg_catalog.pg_extension_config_dump('datalink.dl_directory', '');

---------------------------------------------------
do $$ 
declare file text = '/etc/postgresql-common/dl_directory';
begin 
  if datalink.fileexists(dlvalue(file))
  then execute 'copy datalink.dl_directory from '||quote_literal(file);
  end if;
end 
$$;
