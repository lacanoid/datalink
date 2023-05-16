--
--  datalink
--  version 0.20 lacanoid@ljudmila.org
--
---------------------------------------------------

SET client_min_messages = warning;

COMMENT ON SCHEMA datalink IS 'SQL/MED DATALINK support';

---------------------------------------------------
-- url type
---------------------------------------------------

ALTER extension uri SET schema pg_catalog;
-- CREATE DOMAIN dl_url AS text;
CREATE DOMAIN dl_url AS uri;

---------------------------------------------------
-- datalink type
---------------------------------------------------

CREATE DOMAIN dl_linktype AS text;
CREATE DOMAIN dl_token AS uuid;

CREATE DOMAIN file_path AS text;
COMMENT ON DOMAIN file_path IS 'Absolute file system path';
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_parent    CHECK(value not like all('{../%,%/../%,%/..}'));
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_percent   CHECK(not value ~* '[%]');
ALTER  DOMAIN file_path ADD CONSTRAINT file_path_absolute  CHECK(value like '/%');
/*
CREATE DOMAIN pg_catalog.datalink AS jsonb;
COMMENT ON DOMAIN pg_catalog.datalink IS 'SQL/MED DATALINK like type for storing URLs';
*/

CREATE TYPE pg_catalog.datalink;

CREATE OR REPLACE FUNCTION datalink_in(cstring)
 RETURNS datalink LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_in$function$;
 
CREATE OR REPLACE FUNCTION datalink_out(datalink)
 RETURNS cstring LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_out$function$;
 
CREATE OR REPLACE FUNCTION datalink_recv(internal)
 RETURNS datalink LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_recv$function$;
 
CREATE OR REPLACE FUNCTION datalink_send(datalink)
 RETURNS bytea LANGUAGE internal IMMUTABLE PARALLEL SAFE STRICT
 AS $function$jsonb_send$function$;
 
CREATE TYPE pg_catalog.datalink (
   INPUT = datalink_in,
   OUTPUT = datalink_out,
   SEND = datalink_send,
   RECEIVE = datalink_recv,
   TYPMOD_IN = varchartypmodin,
   TYPMOD_OUT = varchartypmodout,
   INTERNALLENGTH = VARIABLE,
   ALIGNMENT = int4,
   STORAGE = extended,
   CATEGORY = 'U',
   DELIMITER = ',',
   COLLATABLE = false
);

COMMENT ON TYPE pg_catalog.datalink IS 'SQL/MED DATALINK like type for storing URLs';
-- create cast (datalink as jsonb) without function; 
create cast (datalink as jsonb) without function as implicit;
-- create cast (datalink as jsonb) with inout as implicit;
-- create cast (jsonb as datalink) with inout;

---------------------------------------------------
-- link control options
---------------------------------------------------

create type dl_link_control as enum ( 'NO','FILE' );
create type dl_integrity as enum ( 'NONE','SELECTIVE','ALL' );
create type dl_read_access as enum ( 'FS','DB' );
create type dl_write_access as enum ( 'FS','BLOCKED', 'ADMIN', 'TOKEN' );
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
comment on table link_control_options is 'Datalink Link Control Options';
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
   (case $5 when 'YES' then 1 when 'NO' then 0 else 0 end)
   + 2 * (  
   (case $4
     when 'TOKEN' then 3 when 'ADMIN' then 2 when 'BLOCKED' then 1 when 'FS' then 0
     else 0 end)
   + 5 * (
   (case $3 when 'DB' then 1 when 'FS' then 0 else 0 end)
   + 1 * (
   (case $6 when 'DELETE' then 2 when 'RESTORE' then 0 when 'NONE' then 0 else 0 end)
   ))))) as datalink.dl_lco)
$_$;

COMMENT ON FUNCTION dl_lco(
  dl_link_control,dl_integrity,dl_read_access,dl_write_access,dl_recovery,dl_on_unlink)
IS 'Calculate dl_lco from individual options';

create or replace function datalink.dl_lco(regclass regclass,column_name name) returns datalink.dl_lco
as $$
 select case 
        when atttypmod > 0 then atttypmod-4
        else 0 end :: datalink.dl_lco
  from pg_attribute
 where attrelid = $1 and attname = $2
   and atttypid = 'pg_catalog.datalink'::regtype
   and attnum > 0
   and not attisdropped
$$ language sql;
COMMENT ON FUNCTION dl_lco(regclass, name) 
IS 'Find dl_lco for a column';

---------------------------------------------------

CREATE FUNCTION link_control_options(dl_lco) 
RETURNS link_control_options
LANGUAGE sql IMMUTABLE
    AS $_$
select *
  from datalink.link_control_options
 where lco = $1
$_$;

COMMENT ON FUNCTION link_control_options(dl_lco)
IS 'Calculate link_control_options from dl_lco';

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
    unnest(array['FS','BLOCKED','ADMIN','TOKEN']) as wa,
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
CREATE FUNCTION dl_class_adminable(my_class regclass) RETURNS boolean
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
    a.atttypmod,
    a.attoptions,
    a.attfdwoptions,
    c.oid::regclass AS regclass,
    col_description(c.oid, (a.attnum)::integer) AS comment
   FROM pg_class c
   JOIN pg_namespace s ON (s.oid = c.relnamespace)
   JOIN pg_attribute a ON (c.oid = a.attrelid)
   LEFT JOIN pg_attrdef def ON (c.oid = def.adrelid AND a.attnum = def.adnum)
   LEFT JOIN pg_type t ON (t.oid = a.atttypid)
  WHERE t.oid = 'pg_catalog.datalink'::regtype
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
WHERE datalink.dl_class_adminable(regclass);

COMMENT ON VIEW columns
 IS 'Current link control options for datalink dl_columns. You can set them here.';

grant select on columns to public;

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
	    AND datalink.dl_class_adminable(c0_1.oid)
 ),
 classes AS (
         SELECT dl_columns.regclass,
                count(*) AS count,
                max(dl_columns.lco) AS mco
           FROM datalink.dl_columns dl_columns
          WHERE datalink.dl_class_adminable(dl_columns.regclass)
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
             || ' ON ' || regclass::text || '; ', '') ||
    case when links>0 and mco > 0 then
     COALESCE(('CREATE TRIGGER "~RI_DatalinkTrigger" BEFORE INSERT OR UPDATE OR DELETE ON '
               ||  regclass::text) 
               || ' FOR EACH ROW EXECUTE PROCEDURE datalink.dl_trigger_table();', '')
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
  txid bigint not null default txid_current(),
  state file_link_state not null default 'LINK',
  lco dl_lco not null,
  attrelid regclass,
  attnum smallint,
  path file_path primary key,
  address text unique,
  fstat jsonb,
  info jsonb,
  err jsonb
);

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
 where datalink.dl_class_adminable(attrelid);

grant select on linked_files to public;

---------------------------------------------------

CREATE OR REPLACE FUNCTION datalink.file_stat(file_path file_path,
  OUT dev bigint, OUT inode bigint, OUT mode integer, OUT nlink integer,
  OUT uid integer, OUT gid integer,
  OUT rdev integer, OUT size numeric, OUT atime timestamp without time zone,
  OUT mtime timestamp without time zone, OUT ctime timestamp without time zone,
  OUT blksize integer, OUT blocks bigint)
 RETURNS record
  LANGUAGE plperlu
   STRICT
   AS $function$
   use Date::Format;

my ($filename) = @_;
unless(-e $filename) { return undef; }
my (@s) = stat($filename);

return {
 'dev'=>$s[0],'inode'=>$s[1],'mode'=>$s[2],'nlink'=>$s[3],
 'uid'=>$s[4],'gid'=>$s[5],
 'rdev'=>$s[6],'size'=>$s[7],
 'atime'=>time2str("%C",$s[8]),'mtime'=>time2str("%C",$s[9]),'ctime'=>time2str("%C",$s[10]),
 'blksize'=>$s[11],'blocks'=>$s[12]
};
$function$;

COMMENT ON FUNCTION datalink.file_stat(file_path) IS 'Return info record from stat(2)';

---------------------------------------------------

create function file_link(file_path file_path,
                          my_token dl_token,
			                    my_lco dl_lco,
			                    my_regclass regclass,my_attname name)
returns boolean as
$$
declare
 r record;
 fstat jsonb;
 addr text;
 my_attnum smallint;

begin
-- raise notice 'DATALINK LINK:%:%',format('%s.%I',regclass::text,attname),file_path;
 raise notice 'DATALINK LINK:%',file_path;

-- if (datalink.link_control_options(my_lco)).write_access >= 'BLOCKED' then
   if not datalink.is_valid_prefix(file_path) THEN
        raise exception 'datalink exception - referenced file not valid' 
              using errcode = 'HW007',
                    detail = format('unknown path prefix (volume) for %s',file_path),
                    hint = 'run "pg_datalinker add" to add volumes'
                    ;
   end if;
-- end if;
 fstat := row_to_json(datalink.file_stat(file_path))::jsonb;
 if fstat is null then
   fstat := row_to_json(datalink.file_stat(file_path||'#'||my_token))::jsonb;
 end if;
 if fstat is null then
      raise exception 'datalink exception - referenced file not valid' 
            using errcode = 'HW007',
                  detail = format('stat failed for %s',file_path);
 end if;

 addr := array[fstat->>'dev',fstat->>'inode']::text;

 select attnum
   from pg_attribute where attname=my_attname and attrelid=my_regclass
   into my_attnum;
 select * into r
   from datalink.dl_linked_files
   join pg_attribute a using (attrelid,attnum)
  where path = file_path or address = addr
    for update;
 if not found then
   insert into datalink.dl_linked_files (token,path,lco,attrelid,attnum,address)
   values (my_token,file_path,my_lco,my_regclass,my_attnum,addr);
   notify "datalink.linker_jobs"; 
   return true;
 else -- found in dl_linked_files
  -- this is needed to eliminate problems during pg_restore
  if r.token = my_token and r.path = file_path and r.lco = my_lco and
     r.attrelid = my_regclass and r.attnum = my_attnum then
    raise warning 'datalink exception - external file possibly already linked' 
      using detail = format('from %s.%I as ''%s''',r.attrelid::text,r.attname,r.path);
  end if;

  -- already linked ?
  if r.state in ('LINK','LINKED') then
    raise exception 'datalink exception - external file already linked' 
      using errcode = 'HW002', 
      detail = format('from %s.%I as ''%s''',r.attrelid::text,r.attname,r.path);

  -- scheduled for unlinking by datalinker but not processed yet
  elsif r.state in ('UNLINK') then
     if r.lco is distinct from my_lco
     then
        raise exception 'datalink exception - external file already linked' 
          using errcode = 'HW002', 
          detail = format('Cannot change link control option in update');
     end if;
     
     if  r.token is not distinct from my_token
     then -- same file and protection
        update datalink.dl_linked_files
           set state='LINKED',
               attrelid=my_regclass,
               attnum=my_attnum
         where path = file_path and state='UNLINK';
        return true;
     else -- relink
        update datalink.dl_linked_files
           set state='LINK',
               token=my_token,
               attrelid=my_regclass,
               attnum=my_attnum
         where path = file_path and state='UNLINK';
        return true;

        raise exception 'datalink exception - external file already linked' 
        using errcode = 'HW002', 
        detail = format('file is waiting for unlink ''%s'' by datalinker process',r.path);
     end if;

  else
      raise exception 'datalink exception' 
            using errcode = 'HW000', 
                  detail = format('unknown link state %s',r.state);
  end if;
 end if; -- if found
end
$$ language plpgsql strict;
revoke execute on function file_link from public;

---------------------------------------------------

create function file_unlink(file_path file_path)
returns boolean as
$$
declare
 r record;
begin
 raise notice 'DATALINK UNLINK:%',file_path;

 select * into r
   from datalink.dl_linked_files
  where path = file_path
    for update;
 if not found then
      raise exception 'datalink exception - external file not linked' 
            using errcode = 'HW001', 
                  detail = file_path;
 else
  if r.state = 'LINK' then
   update datalink.dl_linked_files
      set state = 'UNLINK',
          token = cast(info->>'token' as datalink.dl_token),
	        lco   = cast(info->>'lco' as datalink.dl_lco)
    where path  = $1 and info is not null
      and state = 'LINK';

   delete from datalink.dl_linked_files
    where path  = $1 and info is null
      and state = 'LINK';

  elsif r.state = 'LINKED' then
   update datalink.dl_linked_files
      set state = 'UNLINK'
    where path  = $1 and state = 'LINKED';

  elsif r.state = 'ERROR' then
   delete from datalink.dl_linked_files
    where path  = $1
      and state = 'ERROR';

  else
      raise exception 'datalink exception' 
            using errcode = 'HW000', 
                  detail = format('unknown link state %s',r.state);
  end if;
 end if;
 notify "datalink.linker_jobs";
 return true;
end
$$ language plpgsql strict;
revoke execute on function file_unlink from public;

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
 RETURNS text
  LANGUAGE sql
  IMMUTABLE STRICT
  AS $function$
select case part
       when 'scheme' then uri_scheme($1)
       when 'server' then uri_host($1)
       when 'userinfo' then uri_userinfo($1)
       when 'host' then uri_host($1)
       when 'path' then uri_unescape(uri_path($1))
       when 'basename' then nullif(to_json(uri_path_array($1))->>-1,'')
       when 'query' then uri_query($1)
       when 'fragment' then uri_fragment($1)
       when 'token' then uri_unescape(uri_fragment($1))
       when 'canonical' then uri_normalize($1)::text
       -- without fragment
       when 'only' then regexp_replace(uri_normalize($1)::text,'#.*','')
       end
$function$
;

COMMENT ON FUNCTION uri_get(uri,text) IS 'Get (extract) parts of URI';

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
      raise exception 'datalink exception' 
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
  loop
    perform datalink.file_unlink(obj.path);
  end loop;

  -- unlink files referenced by dropped dl_columns
  for obj in
    select *
      from
      (select objid::regclass as regclass,
	      objsubid as attnum,
              address_names[3] as attname
         from pg_event_trigger_dropped_objects()
	where object_type = 'table column'
       ) as tdo
      join datalink.dl_linked_files f on f.attrelid=tdo.regclass and f.attnum=tdo.attnum
  loop
    perform datalink.file_unlink(obj.path);
  end loop;

end if;

end
$$;

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
 if url is null or length(url)<=0 then 
   return case when comment is not null then jsonb_build_object('text',comment) end;
 end if;
 my_uri := url;
 my_type := coalesce(linktype, case when url like '/%' then 'FS' else 'URL' end);
 my_uri := case my_type
           when 'URL'  then my_uri::text
	         else format('file://%s',
	              replace(replace(uri_escape(''||my_uri),'%2F','/'),'%23','#'))
           end;
 my_uri := my_uri::datalink.dl_url;
 my_dl  := jsonb_build_object('url',datalink.uri_get(my_uri::datalink.dl_url,'canonical'));
 if comment is not null then
   my_dl:=jsonb_set(my_dl::jsonb,array['text'],to_jsonb(comment));
 end if;
 if my_type not in ('URL','FS') then
    my_dl:=jsonb_set(my_dl::jsonb,array['type'],to_jsonb(my_type));
 end if;
 return my_dl;
end;
$$;

COMMENT ON FUNCTION pg_catalog.dlvalue(text,dl_linktype,text) 
IS 'SQL/MED - Construct a DATALINK value';

CREATE FUNCTION pg_catalog.dlvalue(url text, url_base datalink, comment text DEFAULT NULL) 
RETURNS datalink
    LANGUAGE sql IMMUTABLE
    AS $$select dlvalue(datalink.uri_set(dlurlcompleteonly($2)::uri,'src',$1),'URL',$3)$$;

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
 t1     text;
 u1     text;
begin 
 if has_token > 0 then
  u1 := link->>'url';
  t1 := coalesce(link->>'old',datalink.uri_get(u1,'token'));
  if t1 is not null then
    begin
      token := t1::datalink.dl_token;
    exception
      when sqlstate '22P02' then
        raise exception 'datalink exception - invalid write token'
        using errcode = 'HW004', 
              detail = SQLERRM;
      when others then
        raise exception 'Error code: % name: %',SQLSTATE,SQLERRM;
    end;
    u1 := datalink.uri_set(u1::datalink.dl_url,'token',null);
    link := jsonb_set(link,'{url}',to_jsonb(u1));
  end if;
  if token is null then token := link->>'token'; end if;
  if token is null then token := datalink.dl_newtoken() ; end if;
  link := jsonb_set(link,'{token}',to_jsonb(token));
  link := link - 'old';
 end if; -- has token
 return link;
end
$_$;
COMMENT ON FUNCTION pg_catalog.dlpreviouscopy(link datalink, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value which has an attribute indicating that the previous version of the file should be restored.';

CREATE FUNCTION pg_catalog.dlpreviouscopy(url text, has_token integer default 1) RETURNS datalink
    LANGUAGE sql
    AS $_$select pg_catalog.dlpreviouscopy(pg_catalog.dlvalue($1),$2)$_$;
COMMENT ON FUNCTION pg_catalog.dlpreviouscopy(url text, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value which has an attribute indicating that the previous version of the file should be restored.';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlnewcopy(link datalink, has_token integer default 1) RETURNS datalink
    LANGUAGE plpgsql STRICT
    AS $_$
declare
 token datalink.dl_token;
 t1 text;
 u1 text;
begin 
  u1 := link->>'url';
  if has_token > 0 then
    t1 := coalesce(link->>'token',datalink.uri_get(u1,'token'));
    if t1 is not null then 
      link := jsonb_set(link,'{old}',to_jsonb(t1));
    end if;
  end if;
  u1 := datalink.uri_set(u1::datalink.dl_url,'token',null);
  link := jsonb_set(link,'{url}',to_jsonb(u1));
    -- generate new token
  token := datalink.dl_newtoken();  
  link := jsonb_set(link,'{token}',to_jsonb(token));
 return link;
end
$_$;
COMMENT ON FUNCTION pg_catalog.dlnewcopy(link datalink, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value which has an attribute indicating that the referenced file has changed.';

CREATE FUNCTION pg_catalog.dlnewcopy(url text, has_token integer default 1) RETURNS datalink
    LANGUAGE sql
    AS $_$select pg_catalog.dlnewcopy(pg_catalog.dlvalue($1),$2)$_$;
COMMENT ON FUNCTION pg_catalog.dlnewcopy(url text, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value which has an attribute indicating that the referenced file has changed.';

---------------------------------------------------
-- referential integrity triggers
---------------------------------------------------

CREATE FUNCTION dl_ref(link datalink, link_options dl_lco, regclass regclass, column_name name) 
RETURNS datalink
LANGUAGE plpgsql
    AS $_$
declare
 lco datalink.link_control_options;
 r record;
 has_token integer;
 url text;
begin 
 url := dlurlcomplete($1);
-- raise notice 'DATALINK: dl_ref(''%'',%,%,%)',url,$2,$3,$4;

 has_token := 0;
 if link_options > 0 then
  lco = datalink.link_control_options(link_options);
  if lco.integrity <> 'NONE' then
    -- check if this is a file not a link
    if lco.integrity = 'ALL' and dlurlscheme(link)<>'file' then
        raise exception 'datalink exception - invalid datalink construction' 
              using errcode = 'HW005',
                    detail = 'INTEGRITY ALL can only be used with file URLs',
                    hint = 'make sure you are using a file: URL scheme';
    end if;
    -- check if datalinker in needed and running
    if lco.integrity = 'ALL' and link_options>10 then
      if not datalink.have_datalinker() then
        raise warning 'datalink warning - datalinker required' 
              using errcode = 'HW000',
--                    detail = 'datalinker process is not available',
                    hint = 'make sure pg_datalinker process is running to finalize your commits';
      end if;
    end if;
    if lco.integrity = 'ALL' then has_token := 1; end if;
    -- check if reference exists
    r := datalink.curl_get(url,true);
    if not r.ok and dlurlscheme(link) = 'file' and url ~ '#' then 
      url := replace(url,'#','%23');
      r := datalink.curl_get(url,true);
    end if;
    if not r.ok and dlurlscheme(link) = 'file' then
      r.ok := not (datalink.file_stat(dlurlpathonly(link))).inode is null;
    end if;

    if not r.ok then
      raise exception e'datalink exception - referenced file does not exist\nURL:  %',url 
            using errcode = 'HW003', 
                  detail = format('CURL error %s - %s',r.rc,r.error),
                  hint = 'make sure url is correct and referenced file actually exists';
    end if;
    -- store HTTP response code if one was returned
    if r.rc > 0 then
      link := jsonb_set(link,array['rc'],to_jsonb(r.rc));
    end if;
  end if; -- file link control,  
  
  link := dlpreviouscopy(link,has_token);

  if lco.integrity = 'ALL' and dlurlscheme($1)='file' then
      perform datalink.file_link(dlurlpathonly(link),(link->>'token')::datalink.dl_token,link_options,regclass,column_name);
  end if; -- integrity all

 end if; -- link options
 return link;
end$_$;

---------------------------------------------------

CREATE FUNCTION dl_unref(link datalink, link_options dl_lco, regclass regclass, column_name name) 
RETURNS datalink
    LANGUAGE plpgsql
    AS $_$
declare
 lco datalink.link_control_options;
begin
-- raise notice 'DATALINK: dl_unref(''%'',%,%,%)',dlurlcomplete($1),$2,$3,$4;

 if link_options > 0 then
  lco = datalink.link_control_options(link_options);

  if lco.integrity = 'ALL' then
    perform datalink.file_unlink(dlurlpathonly($1));
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
    perform datalink.file_unlink(path)
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
   if link1 is distinct from link2 then
    if tg_op in ('DELETE','UPDATE') then
       if dlurlcomplete(link1) is not null then
         link1 := datalink.dl_unref(link1,r.lco,tg_relid,r.column_name);
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
   if link1 is distinct from link2 then
    if tg_op in ('INSERT','UPDATE') then
       if dlurlcomplete(link2) is not null then
         -- check for write_access = BLOCKED and prevent updates
	 if opt.write_access = 'BLOCKED' and tg_op='UPDATE' and link1 is not null then
           raise exception 'datalink exception - invalid write permission for update' 
                     using errcode = 'HW006',
                           detail = format('write_access is BLOCKED for column %s,%I',
			                   tg_relid::regclass::text,r.column_name),
                           hint = 'set write_access to ADMIN or TOKEN'
                    ;
	 end if;
         -- check for write_access = TOKEN and prevent updates if needed
	 if opt.write_access = 'TOKEN' and tg_op='UPDATE' and link1 is not null then
 	    if link2->>'old' is null or link2->>'old' is distinct from link1->>'token' then
               raise exception 'datalink exception - invalid write token' 
                         using errcode = 'HW004',
                        detail = format('New value doesn''t contain a matching write token for update of column %s.%I',
		                        tg_relid::regclass::text,r.column_name),
                          hint = 'Supply value with valid write token (dlnewcopy) or set write_access to ADMIN'
                    ;
            end if; -- tokens not matching
	    link2 := link2 - 'old';
	 end if;
         link2 := datalink.dl_ref(link2,r.lco,tg_relid,r.column_name);
         rn := jsonb_set(rn,array[r.column_name::text],to_jsonb(link2));
       end if;
    end if;
   end if;

  end loop; -- link new values

  if tg_op = 'DELETE' then return old; end if;
  new := jsonb_populate_record(new,rn);
  return new;   
end
$_X$;

---------------------------------------------------

CREATE FUNCTION dl_trigger_options() RETURNS trigger
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
    if new.link_control is distinct from old.link_control and new.link_control = 'NO'
    then my_lco := 0; end if;
    perform datalink.modlco(regclass(old.table_name),old.column_name,my_lco);
    return new;
 end if; -- if datalink.columns
 if tg_relid = 'datalink.dl_columns'::regclass then
    my_lco := new.lco;
    perform datalink.modlco(old.regclass,old.column_name,my_lco);
    return new;
 end if; -- if datalink.columns
 return new;
end
$$;

CREATE TRIGGER "columns_instead"
INSTEAD OF UPDATE ON datalink.columns
FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_options();

CREATE TRIGGER "columns_instead"
INSTEAD OF UPDATE ON datalink.dl_columns
FOR EACH ROW
EXECUTE PROCEDURE datalink.dl_trigger_options();

---------------------------------------------------
-- curl functions
---------------------------------------------------

CREATE FUNCTION curl_get(
  INOUT url text, head boolean DEFAULT false, 
  OUT ok boolean, OUT rc integer, OUT body text, OUT error text, OUT elapsed float) 
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

# Check if this is a file on a foreign server
if($url=~m|^file://[^/]|i) {
  my $q=<<'END';
select 
(select srvname from pg_catalog.pg_foreign_server s join pg_catalog.pg_foreign_data_wrapper pfdw on (s.srvfdw=pfdw.oid)
  where srvname = pg_catalog.dlurlserver($1) and pfdw.fdwname = 'postgres_fdw'),
(select extnamespace::regnamespace from pg_catalog.pg_extension where extname = 'dblink')
END
  my $p = spi_prepare($q,'TEXT');
  $fs = spi_exec_prepared($p,$url)->{rows}->[0];
  unless($fs->{extnamespace}) {
    elog(ERROR,'Extension dblink is required for files on foreign servers');
  }
  unless($fs->{srvname}) {
    elog(ERROR,'Foreign server does not exist');
  }
  my $u = $url; $u=~s|^(file://)([^/]+)/|$1/|i;
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

$head = ($head eq't')?1:0;

my $curl = WWW::Curl::Easy->new;
$r{url} = $url;  
$curl->setopt(CURLOPT_USERAGENT,
              "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1");
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_HEADER,$head?1:0);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
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
if(!($retcode==0)) { $r{error} = $curl->strerror($retcode); }

return \%r;
$_$;
revoke execute on function curl_get(text,boolean) from public;

---------------------------------------------------
-- admin functions
---------------------------------------------------

CREATE FUNCTION modlco(
  my_regclass regclass,
  my_column_name name, 
  my_lco dl_lco)
RETURNS link_control_options
    LANGUAGE plpgsql
    AS $_$
declare
 co record;
 obj record;
 e text;
 n bigint;
 my_options datalink.link_control_options;
begin
 select into co *
 from datalink.dl_columns
 where regclass = my_regclass
   and column_name = my_column_name; 

 if not found then
      raise exception 'datalink exception' 
            using errcode = 'HW000',
	    detail = 'Not a DATALINK column';
 end if; 

 select * into my_options
    from datalink.link_control_options
   where lco = my_lco;

 if not found then
      raise exception 'datalink exception' 
            using errcode = 'HW000',
	          detail = format('Invalid link control options (%s)',my_lco),
                  hint = 'see table datalink.link_control_options for valid link control options';
 end if; 

 if my_lco is distinct from co.lco then
   e := format('select count(%I) from %s where %I is not null limit 1',
     my_column_name,cast(my_regclass as text),my_column_name);
   execute e into n;
   if n > 0 then
      raise exception 'datalink exception' 
            using errcode = 'HW000',
	          detail = format('Can''t change link control options; %s non-null values present in column "%s"',
		                  n,my_column_name),
                  hint = format('Perhaps you can "truncate %s"',my_regclass);
   end if;

   -- update fdw options with new lco
   update pg_attribute 
      set -- attfdwoptions=array['dl_lco='||my_lco],
          atttypmod=case when my_lco > 0 then my_lco+4 else -1 end
    where attrelid=my_regclass and attname=my_column_name;

   -- update triggers

   for obj in select * from datalink.dl_trigger_advice()
   where not valid and regclass = my_regclass
   loop
     RAISE NOTICE 'DATALINK DDL:% on %','TRIGGER',obj.regclass;
     execute obj.sql_advice;
   end loop;

end if; -- lco has changed

 return my_options;
end;
$_$;

COMMENT ON FUNCTION modlco(my_regclass regclass, my_column_name name, my_lco dl_lco) 
IS 'Modify link control options for datalink column';

grant usage on schema datalink to public;

---------------------------------------------------
-- SQL/MED functions
---------------------------------------------------

CREATE FUNCTION pg_catalog.dlcomment(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $$ select $1->>'text' $$;
COMMENT ON FUNCTION pg_catalog.dlcomment(datalink) 
IS 'SQL/MED - Returns the comment value, if it exists, from a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcomplete(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select case 
              when $1->>'token' is not null
              then format('%s#%s',$1->>'url',$1->>'token')
              else $1->>'url'
              end;
$_$;
CREATE FUNCTION pg_catalog.dlurlcomplete1(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$select $1->>'url'$_$;
COMMENT ON FUNCTION pg_catalog.dlurlcomplete(datalink) 
IS 'SQL/MED - Returns the data location attribute (URL) from a DATALINK value';

CREATE FUNCTION pg_catalog.dlurlcomplete(text) RETURNS text LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlcomplete(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlcomplete(text) 
IS 'SQL/MED - Returns normalized URL value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcompleteonly(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select datalink.uri_get($1->>'url','only') $_$;
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
   AS $function$select nullif(datalink.uri_get($1->>'url','host'),'')$function$;
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
   AS $function$select datalink.uri_get($1->>'url','scheme')$function$;

COMMENT ON FUNCTION pg_catalog.dlurlscheme(datalink)
     IS 'SQL/MED - Returns the scheme from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlscheme(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlscheme(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlscheme(text) 
IS 'SQL/MED - Returns the scheme from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlpath(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$
   select format('%s%s',
                  datalink.uri_get($1->>'url','path'),
                  '#'||coalesce($1->>'token',datalink.uri_get($1->>'url','token'))
          )
$function$;

COMMENT ON FUNCTION pg_catalog.dlurlpath(datalink)
     IS 'SQL/MED - Returns the file path from DATALINK value';

CREATE FUNCTION pg_catalog.dlurlpath(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dlurlpath(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dlurlpath(text) 
IS 'SQL/MED - Returns the file path from URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlpathonly(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select datalink.uri_get($1->>'url','path')$function$;

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
   AS $function$select coalesce($1->>'type',
                                case when $1->>'url' ilike 'file:///%' then 'FS' else 'URL' end
			       )$function$;

COMMENT ON FUNCTION pg_catalog.dllinktype(datalink)
     IS 'SQL/MED - Returns the link type (URL,FS or custom) of DATALINK value';

CREATE FUNCTION pg_catalog.dllinktype(text) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select dllinktype(dlvalue($1)) $_$;
COMMENT ON FUNCTION pg_catalog.dllinktype(text) 
IS 'SQL/MED - Returns the link type (URL or FS) from URL';

---------------------------------------------------

-- alter domain dl_url add check (value ~* '^(https?|s?ftp|file):///?[^\s/$.?#].[^\s]*$');
alter domain dl_url add check (datalink.uri_get(value,'scheme') is not null);

create function dl_url(datalink) returns uri 
  language sql strict immutable 
as $$select dlurlcomplete($1)::uri$$;

create cast (datalink as uri) with function datalink.dl_url;

---------------------------------------------------

CREATE SERVER IF NOT EXISTS datalink_file_server FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE datalink.dl_prfx (
	prefix text NULL
)
SERVER datalink_file_server
OPTIONS (filename '/etc/postgresql-common/pg_datalinker.prefix');

CREATE FUNCTION datalink.is_valid_prefix(datalink.file_path)
 RETURNS boolean
 LANGUAGE sql
 STABLE STRICT
AS $function$
select exists (
 select prefix
   from datalink.dl_prfx
  where $1 like prefix||'%'
)
$function$
;
COMMENT ON FUNCTION is_valid_prefix(datalink.file_path)
     IS 'Is file path prefixed with a valid prefix?';
---------------------------------------------------
CREATE FUNCTION datalink.read(datalink)
 RETURNS text
 LANGUAGE sql
 STRICT
AS $$select (datalink.curl_get(dlurlcomplete($1))).body$$
;
COMMENT ON FUNCTION read(datalink)
     IS 'Read datalink contents as text';

---------------------------------------------------
CREATE FUNCTION have_datalinker()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
select exists (
 select usename
   from pg_stat_activity
  where datname = current_database() 
    and application_name='pg_datalinker'
)
$function$
;
COMMENT ON FUNCTION have_datalinker()
     IS 'Is datalinker process currently running?';

---------------------------------------------------
-- directories
---------------------------------------------------
create table dl_directory (
  dirname    text collate "C" unique,
  dirpath    file_path not null,
  dirowner   regrole not null,
  diracl     aclitem[],
  dirlco     dl_lco,
  diroptions text[] collate "C"
);
create view directory as
select dirname, 
       coalesce(dirpath,prefix) as dirpath,
       dirowner as dirowner,
       diracl,
       dirlco,
       diroptions
  from dl_prfx dp
  left join dl_directory dir on (dir.dirpath like dp.prefix||'%')
;
COMMENT ON VIEW directory 
     IS 'Configured datalink file system directories';
-- GRANT SELECT ON datalink.directory TO PUBLIC;

---------------------------------------------------
-- volume usage statistics
---------------------------------------------------

create view volume_usage as
WITH f AS (
         SELECT p.prefix,
            lf.path,
            lf.state,
            lf.read_access,
            lf.write_access,
            lf.recovery,
            lf.on_unlink,
            lf.regclass,
            lf.attname,
            lf.owner,
            lf.err,
            (datalink.file_stat(lf.path)).size AS size
           FROM datalink.dl_prfx p
          LEFT JOIN datalink.linked_files lf ON lf.path::text ~~ (p.prefix || '%'::text)
        )
 SELECT f.prefix,
    count(f.path) AS files,
    pg_size_pretty(sum(f.size)) AS size
   FROM f
  GROUP BY GROUPING SETS ((f.prefix), ())
  ORDER BY f.prefix;
COMMENT ON VIEW volume_usage
     IS 'Disk volume usage statistics';
grant select on volume_usage to public;

---------------------------------------------------
-- play tables
---------------------------------------------------

create table sample_datalinks ( link datalink );
grant select on sample_datalinks to public;

update datalink.columns
   set integrity='SELECTIVE'
 where table_name='sample_datalinks' and column_name='link';
  
---------------------------------------------------
-- add stuff to pg_dump 
---------------------------------------------------
-- SELECT pg_catalog.pg_extension_config_dump('datalink.dl_linked_files', '');
SELECT pg_catalog.pg_extension_config_dump('datalink.sample_datalinks', '');
SELECT pg_catalog.pg_extension_config_dump('datalink.dl_directory', '');

