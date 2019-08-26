--
--  datalink
--  version 0.4 lacanoid@ljudmila.org
--
---------------------------------------------------

SET client_min_messages = warning;

COMMENT ON SCHEMA datalink IS 'SQL/MED DATALINK support';

---------------------------------------------------
-- datalink type
---------------------------------------------------

CREATE TYPE   dl_linktype AS ENUM ('URL','FS');
CREATE DOMAIN dl_token AS uuid;
CREATE DOMAIN dl_url AS text CHECK (value ~* '^(https?|s?ftp|file):///?[^\s/$.?#].[^\s]*$');
CREATE DOMAIN pg_catalog.datalink AS jsonb;
COMMENT ON DOMAIN pg_catalog.datalink IS 'SQL/MED DATALINK like type for storing URLs';

---------------------------------------------------
-- SQL/MED datalink functions
---------------------------------------------------

CREATE FUNCTION pg_catalog.dlvalue(url text, linktype dl_linktype DEFAULT 'URL', comment text DEFAULT NULL) 
RETURNS datalink
    LANGUAGE sql IMMUTABLE
    AS $$
with link as (
select jsonb_build_object('url',
         cast(case linktype
           when 'FS' then 'file://' || $1
           when 'URL' then $1
         end as datalink.dl_url)) as js
)
select case 
       when comment is null 
       then link.js
       else jsonb_set(link.js,array['text'],to_jsonb($3))
       end :: pg_catalog.datalink
  from link
$$;
COMMENT ON FUNCTION pg_catalog.dlvalue(text,dl_linktype,text) 
IS 'SQL/MED - Construct a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlcomment(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $$ select $1->>'text' $$;

COMMENT ON FUNCTION pg_catalog.dlcomment(datalink) 
IS 'SQL/MED - Returns the comment value, if it exists, from a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcomplete(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select $1->>'url' $_$;

COMMENT ON FUNCTION pg_catalog.dlurlcomplete(datalink) 
IS 'SQL/MED - Returns the data location attribute (URL) from a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcompleteonly(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select $1->>'url' $_$;

COMMENT ON FUNCTION pg_catalog.dlurlcompleteonly(datalink) 
IS 'SQL/MED - Returns the data location attribute (URL) from a DATALINK value';

---------------------------------------------------
-- link control options
---------------------------------------------------

CREATE TYPE dl_link_control AS ENUM (
    'NO','FILE'
);
CREATE TYPE dl_integrity AS ENUM (
    'NONE','SELECTIVE','ALL'
);
CREATE TYPE dl_read_access AS ENUM (
    'FS','DB'
);
CREATE TYPE dl_write_access AS ENUM (
    'FS','BLOCKED',
    'ADMIN',
    -- 'ADMIN NOT REQUIRING TOKEN FOR UPDATE',
    'ADMIN TOKEN'
    -- 'ADMIN REQUIRING TOKEN FOR UPDATE'
);
CREATE TYPE dl_recovery AS ENUM (
    'NO','YES'
);
CREATE TYPE dl_on_unlink AS ENUM (
    'NONE','RESTORE','DELETE'
);

create cast (text as dl_link_control) with inout as implicit;
create cast (text as dl_integrity) with inout as implicit;
create cast (text as dl_read_access) with inout as implicit;
create cast (text as dl_write_access) with inout as implicit;
create cast (text as dl_recovery) with inout as implicit;
create cast (text as dl_on_unlink) with inout as implicit;

CREATE DOMAIN dl_lco AS integer;
comment on type dl_lco is 'Datalink Link Control Options as atttypmod';

CREATE TABLE dl_link_control_options (
       	lco dl_lco primary key,
    	link_control dl_link_control,
	integrity dl_integrity,
	read_access dl_read_access,
	write_access dl_write_access,
	recovery dl_recovery,
	on_unlink dl_on_unlink
);
comment on table dl_link_control_options is 'Datalink Link Control Options';
grant select on dl_link_control_options to public;

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
 select cast (
   (case $1
     when 'FILE' then 1
     when 'NO' then 0
     else 0
   end) +
   10 * (  
   (case $2
     when 'ALL' then 2
     when 'SELECTIVE' then 1
     when 'NONE' then 0
     else 0
   end) +
   10 * (  
   (case $3
     when 'DB' then 1
     when 'FS' then 0
     else 0
   end) + 
   10 * (  
   (case $4
     when 'BLOCKED' then 3
     when 'ADMIN TOKEN' then 2
     when 'ADMIN' then 1
     when 'FS' then 0
     else 0
   end) +
   10 * (
   (case $5
     when 'YES' then 1
     when 'NO' then 0
     else 0
   end) +
   10 * (
   (case $6
     when 'DELETE' then 2
     when 'RESTORE' then 1
     when 'NONE' then 0
     else 0
   end)
   ))))) as datalink.dl_lco)
$_$;

COMMENT ON FUNCTION dl_lco(
  dl_link_control,dl_integrity,dl_read_access,dl_write_access,dl_recovery,dl_on_unlink)
IS 'Calculate dl_lco from individual options';

---------------------------------------------------

CREATE FUNCTION dl_link_control_options(dl_lco) 
RETURNS dl_link_control_options
LANGUAGE sql IMMUTABLE
    AS $_$
select *
  from datalink.dl_link_control_options
 where lco = $1
/*
select row($1,
           case $1 & 15
             when 0 then 'NO'
             when 1 then 'FILE'
           end,
           case ($1 >> 4) & 15
             when 0 then 'NONE'
             when 1 then 'SELECTIVE'
             when 2 then 'ALL'
           end,
           case ($1 >> 8) & 15
	     when 0 then 'FS'
             when 1 then 'DB'
           end,
           case ($1 >> 12) & 15
             when 0 then 'FS'
             when 1 then 'BLOCKED'
             when 2 then 'ADMIN'
             when 3 then 'ADMIN TOKEN'
           end,
           case ($1 >> 16) & 15
             when 0 then 'NO'
             when 1 then 'YES'
           end,
           case ($1 >> 20) & 15
             when 0 then 'NONE'
             when 1 then 'RESTORE'
             when 2 then 'DELETE'
           end
        ) :: datalink.dl_link_control_options
*/
$_$;

COMMENT ON FUNCTION dl_link_control_options(dl_lco)
IS 'Calculate dl_link_control_options from dl_lco';


---------------------------------------------------
-- init options table
---------------------------------------------------

insert into dl_link_control_options 
with l as (
select datalink.dl_lco(link_control=>lc,integrity=>itg,
                       read_access=>ra,write_access=>wa,
                       recovery=>rec,on_unlink=>unl
                       ),* 
from
    unnest(array['NO','FILE']) as lc,
    unnest(array['NONE','SELECTIVE','ALL']) as itg,
    unnest(array['FS','DB']) as ra,
    unnest(array['FS','BLOCKED','ADMIN','ADMIN TOKEN']) as wa,
    unnest(array['NO','YES']) as rec,
    unnest(array['NONE','RESTORE','DELETE']) as unl
)
-- valid option combinations per SQL/MED 2011 
select * from l
 where dl_lco = 0
    or lc='FILE' and itg='SELECTIVE' and ra='FS' and wa='FS' and unl='NONE' and rec='NO'
    or lc='FILE' and itg='ALL' and (
       ra='FS' and wa='FS' and unl='NONE' and rec='NO'
       or
       ra='FS' and wa='BLOCKED' and unl='RESTORE'
       or
       ra='DB' and wa<>'FS' and unl<>'NONE'
    )
;

CREATE FUNCTION dl_class_adminable(my_class regclass) RETURNS boolean
    LANGUAGE sql
    AS $_$
select exists (select *
  from pg_class c
  join pg_user u on (u.usesysid=c.relowner)
 where c.oid=$1
  and (u.usename = CURRENT_ROLE or 
  EXISTS ( SELECT pg_user.usesuper
             FROM pg_user
            WHERE pg_user.usename = CURRENT_ROLE AND pg_user.usesuper)
  )
)
$_$;

---------------------------------------------------
-- definition tables
---------------------------------------------------

CREATE TABLE dl_column_options (
    regclass regclass NOT NULL,
    column_name name NOT NULL,
    lco dl_lco DEFAULT 0 NOT NULL
);
COMMENT ON TABLE dl_column_options 
IS 'Current link control options';
ALTER TABLE ONLY dl_column_options
    ADD CONSTRAINT dl_column_options_pkey PRIMARY KEY (regclass, column_name);
ALTER TABLE ONLY dl_column_options
    ADD CONSTRAINT dl_column_options_valid foreign key (lco) references dl_link_control_options(lco);

---------------------------------------------------
-- views
---------------------------------------------------

CREATE VIEW dl_columns AS
 SELECT u.usename AS table_owner,
    s.nspname AS schema_name,
    c.relname AS table_name,
    a.attname AS column_name,
    COALESCE((ad.lco)::integer, 0) AS lco,
    a.attnotnull AS not_null,
    a.attislocal AS islocal,
    a.attnum AS ord,
    c.oid::regclass AS regclass,
    a.atttypmod,
    a.attoptions,
    a.attfdwoptions,
    col_description(c.oid, (a.attnum)::integer) AS comment
   FROM (((((((pg_class c
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     JOIN pg_attribute a ON ((c.oid = a.attrelid)))
     JOIN pg_user u ON ((c.relowner = u.usesysid)))
     LEFT JOIN pg_attrdef def ON (((c.oid = def.adrelid) AND (a.attnum = def.adnum))))
     LEFT JOIN pg_type t ON ((t.oid = a.atttypid)))
     JOIN pg_namespace tn ON ((tn.oid = t.typnamespace)))
     LEFT JOIN dl_column_options ad ON 
      ((ad.regclass = c.oid AND ad.column_name = a.attname)))
     LEFT JOIN dl_link_control_options lco ON (lco.lco=ad.lco)
  WHERE ((c.relkind = 'r'::"char") AND (a.attnum > 0) AND 
         t.oid = 'pg_catalog.datalink'::regtype AND
          (NOT a.attisdropped))
  ORDER BY s.nspname, c.relname, a.attnum;


---------------------------------------------------

CREATE VIEW dl_triggers AS
 WITH
 triggers AS (
         SELECT c0_1.oid,
            t0.tgname
           FROM (pg_trigger t0
             JOIN pg_class c0_1 ON ((t0.tgrelid = c0_1.oid)))
          WHERE ((t0.tgname = '~RI_DatalinkTrigger'::name) AND dl_class_adminable((c0_1.oid)::regclass))
 ),
 classes AS (
         SELECT dl_columns.regclass,
            count(*) AS count,
            max(dl_columns.lco) AS mco
           FROM dl_columns dl_columns
          WHERE dl_class_adminable(dl_columns.regclass)
          GROUP BY dl_columns.regclass
 )
 SELECT u.usename AS owner,
    (COALESCE(c.regclass, t.oid))::regclass AS regclass,
    COALESCE(c.count, (0)::bigint) AS links,
    c.mco,
    t.tgname
   FROM (((triggers t
     FULL JOIN classes c ON ((t.oid = c.regclass)))
     JOIN pg_class c0 ON ((c0.oid = COALESCE(c.regclass, t.oid))))
     JOIN pg_user u ON ((u.usesysid = c0.relowner)))
  ORDER BY ((COALESCE(c.regclass, t.oid))::regclass)::text;
grant select on dl_triggers to public;

---------------------------------------------------

CREATE FUNCTION dl_sql_advice(
    OUT advice_type text, OUT owner name, OUT regclass regclass, 
    OUT valid boolean, OUT identifier name, OUT links bigint, OUT sql_advice text) 
    RETURNS SETOF record
    LANGUAGE sql
    AS $$
SELECT 'TRIGGER'::text AS advice_type,
    owner,
    regclass AS regclass,
    not (tgname is null or links = 0) as valid,
    tgname AS identifier,
    links,
    COALESCE('DROP TRIGGER IF EXISTS ' || quote_ident(tgname) 
             || ' ON ' || regclass::text || '; ', '') ||
    COALESCE('DROP TRIGGER IF EXISTS ' || quote_ident(tgname||'2') 
             || ' ON ' || regclass::text || '; ', '') ||
    case when links>0 then
     COALESCE(('CREATE TRIGGER "~RI_DatalinkTrigger" BEFORE INSERT OR UPDATE OR DELETE ON '
               ||  regclass::text) 
               || ' FOR EACH ROW EXECUTE PROCEDURE datalink.dl_trigger_table();', '')
	       ||
     COALESCE(('CREATE TRIGGER "~RI_DatalinkTrigger2" BEFORE TRUNCATE ON '
               ||  regclass::text) 
               || ' FOR EACH STATEMENT EXECUTE PROCEDURE datalink.dl_trigger_table();', '') 
    else ''
    end AS sql_advice
   FROM datalink.dl_triggers
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
  regclass regclass,
  attname name,
  path text primary key,
  address text unique,
  fstat jsonb,
  info jsonb
);

-----

CREATE OR REPLACE FUNCTION datalink.file_stat(file_path text,
  OUT dev bigint, OUT inode bigint, OUT mode integer, OUT nlink integer, OUT uid integer, OUT gid integer,
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

COMMENT ON FUNCTION datalink.file_stat(text) IS 'Return info record from stat(2)';
-----

create function file_link(file_path text,token dl_token,lco dl_lco,regclass regclass,attname name) returns boolean as
$$
declare
 r record;
 fstat jsonb;
 addr text;
begin
-- raise notice 'DATALINK LINK:%:%',format('%s.%I',regclass::text,attname),file_path;
 raise notice 'DATALINK LINK:%',file_path;

 fstat := row_to_json(datalink.file_stat(file_path))::jsonb;

 if fstat is null then
      raise exception 'Referenced file not valid' 
            using errcode = 'HW007',
                  detail = file_path;
 end if;

 addr := array[fstat->>'dev',fstat->>'inode']::text;
 select * into r
   from datalink.dl_linked_files
  where path = file_path or address = addr
    for update;
 if not found then
   insert into datalink.dl_linked_files (token,path,lco,regclass,attname,fstat,address)
   values (token,file_path,lco,regclass,attname,fstat,addr);
   return true;
 else
  if r.state in ('LINK','LINKED') then
      raise exception 'External file already linked' 
            using errcode = 'HW002', 
                  detail = format('from %s.%I as ''%s''',r.regclass::text,r.attname,r.path);
  else
      raise exception 'Datalink exception' 
            using errcode = 'HW000', 
                  detail = format('unknown link state %s',r.state);
  end if;
 end if;
end
$$ language plpgsql strict;

create function file_unlink(file_path text,token dl_token,lco dl_lco,regclass regclass,attname name) returns boolean as
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
      raise exception 'External file not linked' 
            using errcode = 'HW001', 
                  detail = file_path;
 else
  if r.state = 'LINK' then
   delete from datalink.dl_linked_files
    where path = $1
      and state = 'LINK';
  elsif r.state = 'LINKED' then
   update datalink.dl_linked_files
      set state = 'UNLINK'
    where path = $1 and state = 'LINKED';
  else
      raise exception 'Datalink exception' 
            using errcode = 'HW000', 
                  detail = format('unknown link state %s',r.state);
  end if;
 end if;
 return true;
end
$$ language plpgsql strict;

---------------------------------------------------
-- event triggers
---------------------------------------------------

CREATE FUNCTION dl_trigger_event() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
declare
 obj record;
begin
-- RAISE NOTICE 'DATALINK % trigger: %', tg_event, tg_tag;

 if tg_event = 'ddl_command_end' then

 if tg_tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO','ALTER TABLE') 
 then
  -- update triggers on tables with datalinks
   for obj in select * from datalink.dl_sql_advice()
   where advice_type = 'TRIGGER' and not valid
   loop
     RAISE NOTICE 'DATALINK DDL:% on %',obj.advice_type,obj.regclass;
     execute obj.sql_advice;
   end loop;
 end if;

 elsif tg_event = 'sql_drop' then
  -- unlink files referenced by dropped tables
  for obj in
   select *
     from datalink.dl_linked_files
    where regclass in 
      (select tdo.objid
         from pg_event_trigger_dropped_objects() tdo
	where object_type = 'table'
       )
  loop
    perform datalink.file_unlink(obj.path,obj.token,obj.lco,obj.regclass,obj.attname);
    delete from datalink.dl_column_options where regclass=obj.regclass and column_name=obj.attname;
  end loop;

-- unlink files referenced by dropped columns
  for obj in
    select *
      from
      (select objid::regclass as regclass,
              address_names[3] as attname
         from pg_event_trigger_dropped_objects()
	where object_type = 'table column'
       ) as tdo
      join datalink.dl_linked_files f on f.regclass=tdo.regclass and f.attname=tdo.attname
  loop
    perform datalink.file_unlink(obj.path,obj.token,obj.lco,obj.regclass,obj.attname);
    delete from datalink.dl_column_options where regclass=obj.regclass and column_name=obj.attname;
  end loop;
end if;

end
$$;

---------------------------------------------------

create event trigger datalink_event_trigger_end
on ddl_command_end execute procedure dl_trigger_event();

create event trigger datalink_event_trigger_drop
on sql_drop execute procedure dl_trigger_event();

---------------------------------------------------
-- SQL/MED update functions
---------------------------------------------------

CREATE OR REPLACE FUNCTION uuid_generate_v4() RETURNS uuid
    LANGUAGE c PARALLEL SAFE STRICT
    AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$;

CREATE FUNCTION dl_newtoken() RETURNS dl_token
    LANGUAGE sql
    AS $$
select cast(datalink.uuid_generate_v4() as datalink.dl_token);
$$;

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlpreviouscopy(link datalink, has_token integer) RETURNS datalink
    LANGUAGE plpgsql STRICT
    AS $_$
declare
 token datalink.dl_token;
begin 
 if has_token > 0 then
  token := link->>'token';
  if token is null then token := datalink.dl_newtoken() ; end if;
  link := jsonb_set(link,'{token}',to_jsonb(token));
--  link.token := token;
 end if;
 return link;
end
$_$;
COMMENT ON FUNCTION pg_catalog.dlpreviouscopy(link datalink, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value which has an attribute indicating that the previous version of the file should be restored.';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlnewcopy(link datalink, has_token integer) RETURNS datalink
    LANGUAGE plpgsql STRICT
    AS $_$
declare
 token datalink.dl_token;
begin 
 if has_token > 0 then
  token := datalink.dl_newtoken();
  link := jsonb_set(link,'{token}',to_jsonb(token));
--  link.token := datalink.dl_newtoken();
 end if;
 return link;
end
$_$;
COMMENT ON FUNCTION pg_catalog.dlnewcopy(link datalink, has_token integer) 
IS 'SQL/MED - Returns a DATALINK value which has an attribute indicating that the referenced file has changed.';

---------------------------------------------------
-- referential integrity triggers
---------------------------------------------------

CREATE FUNCTION dl_ref(link datalink, link_options dl_lco, regclass regclass, column_name name) 
RETURNS datalink
LANGUAGE plpgsql
    AS $_$
declare
 lco datalink.dl_link_control_options;
 r record;
 has_token integer;
 url text;
begin 
 url := dlurlcomplete($1);
-- raise notice 'DATALINK: dl_ref(''%'',%,%,%)',url,$2,$3,$4;

 has_token := 0;
 if link_options > 0 then
  lco = datalink.dl_link_control_options(link_options);
  if lco.link_control = 'FILE' then
    -- check if reference exists
    has_token := 1;
    r := datalink.curl_get(url,true);
    if not r.ok then
      raise exception 'Referenced file does not exit' 
            using errcode = 'HW003', 
                  detail = url;
    end if;
  end if; -- file link control,
  
  link := dlpreviouscopy(link,has_token);

  if lco.integrity = 'ALL' then
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
 lco datalink.dl_link_control_options;
begin
-- raise notice 'DATALINK: dl_unref(''%'',%,%,%)',dlurlcomplete($1),$2,$3,$4;

 if link_options > 0 then
  lco = datalink.dl_link_control_options(link_options);

  if lco.integrity = 'ALL' then
    perform datalink.file_unlink(dlurlpathonly($1),(link->>'token')::datalink.dl_token,link_options,regclass,column_name);
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
begin
  if tg_op = 'TRUNCATE' then
    perform datalink.file_unlink(path,token,lco,regclass,attname)
       from datalink.dl_linked_files
      where regclass = tg_relid; 
    return new;
  end if;

  if tg_op in ('DELETE','UPDATE') then
	ro := row_to_json(old)::jsonb;
  end if;
  
  if tg_op in ('INSERT','UPDATE') then
	rn := row_to_json(new)::jsonb;
  end if;

  for r in
  select column_name,lco 
    from datalink.dl_columns 
   where regclass = tg_relid

  loop
   link1 := null; link2 := null;

   if tg_op in ('DELETE','UPDATE') then link1 := ro->r.column_name; end if;
   if tg_op in ('INSERT','UPDATE') then link2 := rn->r.column_name; end if;

   if link1 is distinct from link2 then
   
    if tg_op in ('DELETE','UPDATE') then
       if dlurlcomplete(link1) is not null then
         link1 := datalink.dl_unref(link1,r.lco,tg_relid,r.column_name);
       end if;
    end if;
  
    if tg_op in ('INSERT','UPDATE') then
       if dlurlcomplete(link2) is not null then
         link2 := datalink.dl_ref(link2,r.lco,tg_relid,r.column_name);
         rn := jsonb_set(rn,array[r.column_name::text],to_jsonb(link2));
       end if;
    end if;
   end if;

  end loop;

  if tg_op = 'DELETE' then return old; end if;

  new := jsonb_populate_record(new,rn);
  return new;   
end
$_X$;

---------------------------------------------------
-- uri functions
---------------------------------------------------

CREATE OR REPLACE FUNCTION uri_get(url text, part text)
 RETURNS text
  LANGUAGE plperlu
  AS $function$
  use URI;
  use File::Basename;

my $u=URI->new($_[0]);
my $part=$_[1]; lc($part);
if($part eq 'scheme') { return $u->scheme(); }
if($part eq 'path') { return $u->path(); }
if($part eq 'basename') { return basename($u->path()); }
if($part eq 'dirname') { return dirname($u->path()); }
if($part eq 'authority') { return $u->authority(); }
if($part eq 'path_query') { return $u->path_query(); }
if($part eq 'query_form') { return $u->query_form(); }
if($part eq 'query_keywords') { return $u->query_keywords(); }
if($part eq 'userinfo') { return $u->userinfo(); }
if($part eq 'host') { return $u->host(); }
if($part eq 'domain') { my $d = $u->host(); $d=~s|^www\.||; return $d; }
if($part eq 'port') { return $u->port(); }
if($part eq 'host_port') { return $u->host_port(); }
if($part eq 'query') { return $u->query(); }
if($part eq 'fragment') { return $u->fragment(); }
if($part eq 'token') { return $u->fragment(); }
if($part eq 'canonical') { return $u->canonical(); }
elog(ERROR,"Unknown part '$path'.");
$function$
;

COMMENT ON FUNCTION uri_get(text,text) IS 'Get (extract) parts of URI';

CREATE OR REPLACE FUNCTION uri_set(url text, part text, val text)
 RETURNS text
  LANGUAGE plperlu
  AS $function$
  use URI;
  my $u=URI->new($_[0]);
  my $part=$_[1]; lc($part);
  my $v=$_[2];
  if($part eq 'scheme') { $u->scheme($v); }
  elsif($part eq 'path') {  $u->path($v); }
  elsif($part eq 'authority') {  $u->authority($v); }
  elsif($part eq 'path_query') {  $u->path_query($v); }
  elsif($part eq 'query_form') {  $u->query_form($v); }
  elsif($part eq 'query_keywords') {  $u->query_keywords($v); }
  elsif($part eq 'userinfo') {  $u->userinfo($v); }
  elsif($part eq 'host') {  $u->host($v); }
  elsif($part eq 'port') {  $u->port($v); }
  elsif($part eq 'host_port') {  $u->host_port($v); }
  elsif($part eq 'query') {  $u->query($v); }
  elsif($part eq 'fragment') {  $u->fragment($v); }
  elsif($part eq 'token') {  $u->fragment($v); }
  else { elog(ERROR,"Unknown part '$path'."); }
  return $u->as_string;
  $function$
  ;

COMMENT ON FUNCTION uri_set(text,text,text) IS 'Set (replace) parts of URI';


---------------------------------------------------
-- curl functions
---------------------------------------------------

CREATE FUNCTION curl_get(
  url text, head boolean DEFAULT false, 
  OUT ok boolean, OUT response_code integer, OUT response_body text, OUT retcode integer, OUT error text) 
RETURNS record
LANGUAGE plperlu
AS $_$
my ($url,$head)=@_;

use strict;
use warnings;
use WWW::Curl::Easy;

$head = ($head eq't')?1:0;

my $curl = WWW::Curl::Easy->new;
my %r;
  
$curl->setopt(CURLOPT_USERAGENT, "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.1) Gecko/20061204 Firefox/2.0.0.1");
$curl->setopt(CURLOPT_URL, $url);
$curl->setopt(CURLOPT_HEADER,$head?1:0);
$curl->setopt(CURLOPT_FOLLOWLOCATION, 1);
if($head) { $curl->setopt(CURLOPT_TIMEOUT, 5); }

# A filehandle, reference to a scalar or reference to a typeglob can be used here.
my $response_header;
my $response_body;
if($head) { $curl->setopt(CURLOPT_WRITEHEADER,\$response_header); }
else      { $curl->setopt(CURLOPT_WRITEDATA,\$response_body); }

# Starts the actual request
my $retcode = $curl->perform;

# Looking at the results...
$r{ok} = ($retcode==0)?'yes':'no';
$r{retcode} = $retcode;
$r{response_code} = $curl->getinfo(CURLINFO_HTTP_CODE);
if($head) { $r{response_body} = $response_header; }
else      { $r{response_body} = $response_body; }
if(!($retcode==0)) { $r{error} = $curl->strerror($retcode); }

return \%r;
$_$;
revoke execute on function curl_get(text,boolean) from public;

---------------------------------------------------
-- admin functions
---------------------------------------------------

CREATE FUNCTION dl_chattr(
  my_regclass regclass,
  my_column_name name, 
  my_lco dl_lco)
RETURNS dl_link_control_options
    LANGUAGE plpgsql
    AS $_$
declare
 my_id regclass;
 e text;
 n bigint;
 my_options datalink.dl_link_control_options;
begin
 select into my_id regclass
 from datalink.dl_columns
 where regclass = my_regclass
   and column_name = my_column_name; 

 if not found then
      raise exception 'Datalink exception' 
            using errcode = 'HW000',
	    detail = 'Not a DATALINK column';
 end if; 

 select * into my_options
    from datalink.dl_link_control_options
   where lco = my_lco;

 if not found then
      raise exception 'Datalink exception' 
            using errcode = 'HW000',
	    detail = format('Invalid link control options (%s)',my_lco);
 end if; 

 e := format('select count(%I) from %s where %I is not null limit 1',
   my_column_name,cast(my_regclass as text),my_column_name);
 execute e into n;
 if n > 0 then
   raise exception 'Can''t change link control options; % non-null values present in column "%"',n,my_column_name;
 end if;
 
 update datalink.dl_column_options 
 set lco = my_lco
 where regclass = my_regclass
   and column_name = my_column_name;

 if not found then
  insert into datalink.dl_column_options (regclass,column_name,lco)
  values (my_regclass,my_column_name,my_lco);
 end if;

 return my_options;
end;
$_$;

COMMENT ON FUNCTION dl_chattr(my_regclass regclass, my_column_name name, my_lco dl_lco) 
IS 'Set link control options for datalink column (buggy)';

grant usage on schema datalink to public;

---------------------------------------------------
-- SQL/MED functions
---------------------------------------------------

CREATE OR REPLACE FUNCTION pg_catalog.dlurlserver(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select datalink.uri_get($1->>'url','host')$function$;

COMMENT ON FUNCTION pg_catalog.dlurlserver(datalink) IS 'SQL/MED - Returns the file server from a DATALINK value';

---------------

CREATE OR REPLACE FUNCTION pg_catalog.dlurlscheme(datalink)
RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select datalink.uri_get($1->>'url','scheme')$function$;

COMMENT ON FUNCTION pg_catalog.dlurlscheme(datalink) IS 'SQL/MED - Returns the scheme from a DATALINK value';

---------------

CREATE OR REPLACE FUNCTION pg_catalog.dlurlpath(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select datalink.uri_get($1->>'url','path')$function$;

COMMENT ON FUNCTION pg_catalog.dlurlpath(datalink) IS 'SQL/MED - Returns the file path from a DATALINK value';

---------------

CREATE OR REPLACE FUNCTION pg_catalog.dlurlpathonly(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select datalink.uri_get($1->>'url','path')$function$;

COMMENT ON FUNCTION pg_catalog.dlurlpathonly(datalink) IS 'SQL/MED - Returns the file path from a DATALINK value';

---------------------------------------------------
-- play tables
---------------------------------------------------

CREATE OR REPLACE FUNCTION pg_catalog.dllinktype(datalink)
 RETURNS text
  LANGUAGE sql
   IMMUTABLE STRICT
   AS $function$select case when $1->>'url' ilike 'file:///%' then 'FS' else 'URL' end$function$;

COMMENT ON FUNCTION pg_catalog.dllinktype(datalink) IS 'SQL/MED - Returns the link type (URL or FS) of a DATALINK value';

create table sample_datalinks ( id serial primary key, link datalink );
grant select,insert,update,delete on sample_datalinks to public;
grant usage on sequence sample_datalinks_id_seq to public;
select dl_chattr('sample_datalinks','link',dl_lco(link_control=>'FILE',integrity=>'ALL'));

