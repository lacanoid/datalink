--
--  datalink
--  version 0.3 lacanoid@ljudmila.org
--
---------------------------------------------------

SET client_min_messages = warning;

---------------------------------------------------
-- datalink type
---------------------------------------------------

CREATE TYPE dl_linktype AS ENUM ('URL','FS');
CREATE DOMAIN dl_token AS uuid;
CREATE DOMAIN pg_catalog.datalink AS jsonb;
CREATE DOMAIN dl_url AS text CHECK (value ~* '^(https?|s?ftp|file):///?[^\s/$.?#].[^\s]*$');

---------------------------------------------------
-- datalink functions
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
IS 'SQL/MED - construct a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlcomment(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $$ select $1->>'text' $$;

COMMENT ON FUNCTION pg_catalog.dlcomment(datalink) 
IS 'SQL/MED - returns the comment value, if it exists, from a DATALINK value';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcomplete(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select $1->>'url' $_$;

COMMENT ON FUNCTION pg_catalog.dlurlcomplete(datalink) 
IS 'SQL/MED - returns the data location attribute from a DATALINK value with a link type of URL';

---------------------------------------------------

CREATE FUNCTION pg_catalog.dlurlcompleteonly(datalink) RETURNS text
    LANGUAGE sql STRICT IMMUTABLE
AS $_$ select $1->>'url' $_$;

COMMENT ON FUNCTION pg_catalog.dlurlcompleteonly(datalink) 
IS 'SQL/MED - returns the data location attribute from a DATALINK value with a link type of URL';

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
CREATE TYPE dl_on_unlink AS ENUM (
    'NONE','RESTORE','DELETE'
);
CREATE TYPE dl_recovery AS ENUM (
    'NO','YES'
);
CREATE TYPE dl_link_control_options AS (
	link_control dl_link_control,
	integrity dl_integrity,
	read_access dl_read_access,
	write_access dl_write_access,
	recovery dl_recovery,
	on_unlink dl_on_unlink
);
comment on type dl_link_control_options is 'Datalink Link Control Options';

CREATE DOMAIN dl_lco AS integer;
comment on type dl_lco is 'Datalink Link Control Options as atttypmod';

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
   16 * (  
   (case $2
     when 'ALL' then 2
     when 'SELECTIVE' then 1
     when 'NONE' then 0
     else 0
   end) +
   16 * (  
   (case $3
     when 'DB' then 1
     when 'FS' then 0
     else 0
   end) + 
   16 * (  
   (case $4
     when 'BLOCKED' then 3
     when 'ADMIN TOKEN' then 2
     when 'ADMIN' then 1
     when 'FS' then 0
     else 0
   end) +
   16 * (
   (case $5
     when 'YES' then 1
     when 'NO' then 0
     else 0
   end) +
   16 * (
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
select row(case $1 & 15
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
$_$;

COMMENT ON FUNCTION dl_link_control_options(dl_lco)
IS 'Calculate dl_link_control_options from dl_lco';

---------------------------------------------------

CREATE FUNCTION dl_class_adminable(my_class regclass) RETURNS boolean
    LANGUAGE sql
    AS $_$
select exists (select *
 from pg_class c
join pg_user u on (u.usesysid=c.relowner)
where c.oid=$1
  and (u.usename = "current_user"() or 
  EXISTS ( SELECT pg_user.usesuper
           FROM pg_user
          WHERE pg_user.usename = "current_user"() AND pg_user.usesuper)
  )
)
$_$;

---------------------------------------------------
-- definition tables
---------------------------------------------------

CREATE TABLE dl_optionsdef (
    schema_name name NOT NULL,
    table_name name NOT NULL,
    column_name name NOT NULL,
    control_options dl_lco DEFAULT 0 NOT NULL
);
COMMENT ON TABLE dl_optionsdef 
IS 'Current link control options';
ALTER TABLE ONLY dl_optionsdef
    ADD CONSTRAINT dl_optionsdef_pkey PRIMARY KEY (schema_name, table_name, column_name);

---------------------------------------------------
-- views
---------------------------------------------------

CREATE VIEW dl_columns AS
 SELECT u.usename AS table_owner,
    s.nspname AS schema_name,
    c.relname AS table_name,
    a.attname AS column_name,
    COALESCE((ad.control_options)::integer, 0) AS control_options,
    a.attnotnull AS not_null,
    col_description(c.oid, (a.attnum)::integer) AS comment,
    a.attislocal AS islocal,
    a.attnum AS ord,
    cast(regclass(c.oid) as text)||'.'||quote_ident(a.attname) AS sql_identifier,
    c.oid AS regclass,
    a.atttypmod,
    c.oid AS relid
   FROM (((((((pg_class c
     JOIN pg_namespace s ON ((s.oid = c.relnamespace)))
     JOIN pg_attribute a ON ((c.oid = a.attrelid)))
     JOIN pg_user u ON ((c.relowner = u.usesysid)))
     LEFT JOIN pg_attrdef def ON (((c.oid = def.adrelid) AND (a.attnum = def.adnum))))
     LEFT JOIN pg_type t ON ((t.oid = a.atttypid)))
     JOIN pg_namespace tn ON ((tn.oid = t.typnamespace)))
     LEFT JOIN dl_optionsdef ad ON 
      (((ad.schema_name = s.nspname) AND (ad.table_name = c.relname) AND (ad.column_name = a.attname))))
  WHERE ((c.relkind = 'r'::"char") AND (a.attnum > 0) AND 
         t.oid = 'pg_catalog.datalink'::regtype AND
          (NOT a.attisdropped))
  ORDER BY s.nspname, c.relname, a.attnum;


---------------------------------------------------

CREATE VIEW dl_triggers AS
 WITH triggers AS (
         SELECT c0_1.oid,
            t0.tgname
           FROM (pg_trigger t0
             JOIN pg_class c0_1 ON ((t0.tgrelid = c0_1.oid)))
          WHERE ((t0.tgname = '~RI_DatalinkTrigger'::name) AND dl_class_adminable((c0_1.oid)::regclass))
        ), classes AS (
         SELECT dl_columns.relid,
            count(*) AS count,
            max(dl_columns.control_options) AS mco
           FROM dl_columns dl_columns
          WHERE dl_class_adminable((dl_columns.relid)::regclass)
          GROUP BY dl_columns.relid
        )
 SELECT u.usename AS owner,
    (COALESCE(c.relid, t.oid))::regclass AS regclass,
    COALESCE(c.count, (0)::bigint) AS links,
    c.mco,
    t.tgname
   FROM (((triggers t
     FULL JOIN classes c ON ((t.oid = c.relid)))
     JOIN pg_class c0 ON ((c0.oid = COALESCE(c.relid, t.oid))))
     JOIN pg_user u ON ((u.usesysid = c0.relowner)))
  ORDER BY ((COALESCE(c.relid, t.oid))::regclass)::text;
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
    case when links>0 then
     COALESCE(('CREATE TRIGGER "~RI_DatalinkTrigger" BEFORE INSERT OR UPDATE OR DELETE ON '::text 
               ||  regclass::text) 
               || ' FOR EACH ROW EXECUTE PROCEDURE datalink.dl_ri_trigger()'::text, ''::text) 
    else ''
    end AS sql_advice
   FROM datalink.dl_triggers
$$;

---------------------------------------------------
-- event triggers
---------------------------------------------------

CREATE FUNCTION dl_event_trigger() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
declare
 obj record;
begin
 --  RAISE NOTICE 'DATALINK % trigger: %', tg_event, tg_tag;
  

 if tg_tag in ('CREATE TABLE','CREATE TABLE AS','SELECT INTO','ALTER TABLE') 
 then
   for obj in select * from datalink.dl_sql_advice()
   where advice_type = 'TRIGGER' and not valid
   loop
     RAISE NOTICE 'DATALINK DDL: %',obj.sql_advice;
     execute obj.sql_advice;
   end loop;
 end if;

end
$$;

---------------------------------------------------

create event trigger datalink_event_trigger
on ddl_command_end
execute procedure dl_event_trigger();

---------------------------------------------------
-- SQL/MED update functions
---------------------------------------------------

CREATE FUNCTION dl_newtoken() RETURNS dl_token
    LANGUAGE sql
    AS $$
select cast(public.uuid_generate_v4() as datalink.dl_token);
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
IS 'SQL/MED - returns a DATALINK value which has an attribute indicating that the previous version of the file should be restored.';

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
IS 'SQL/MED - returns a DATALINK value which has an attribute indicating that the referenced file has changed.';

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
 raise notice 'DATALINK: dl_ref(''%'',%,%,%)',url,$2,$3,$4;

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
                  detail = format('[%s.%I] %s',regclass::text,column_name,url);
    end if;
  end if;
  
  link := dlpreviouscopy(link,has_token);
 end if;
 return link;
end$_$;

---------------------------------------------------

CREATE FUNCTION dl_unref(link datalink, link_options dl_lco, regclass regclass, column_name name) 
RETURNS datalink
    LANGUAGE plpgsql
    AS $_$
begin
 raise notice 'DATALINK: dl_unref(''%'',%,%,%)',dlurlcomplete($1),$2,$3,$4;
 return $1;
end$_$;


---------------------------------------------------

CREATE FUNCTION dl_ri_trigger() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_X$
declare
  r record;
  ro jsonb;
  rn jsonb;
  link pg_catalog.datalink;
begin
  if tg_op in ('DELETE','UPDATE') then
	ro := row_to_json(old)::jsonb;
  end if;
  
  if tg_op in ('INSERT','UPDATE') then
	rn := row_to_json(new)::jsonb;
  end if;

  for r in
  select column_name,control_options 
    from datalink.dl_columns 
   where regclass = tg_relid

  loop

	link := null;
    if tg_op in ('DELETE','UPDATE') then
	   link := ro->r.column_name;
       if dlurlcomplete(link) is not null then
         link := datalink.dl_unref(link,r.control_options,tg_relid,r.column_name);
       end if;
    end if;
  
	link := null;
    if tg_op in ('INSERT','UPDATE') then
       link := rn->r.column_name;
       if dlurlcomplete(link) is not null then
         link := datalink.dl_ref(link,r.control_options,tg_relid,r.column_name);
         rn := jsonb_set(rn,array[r.column_name::text],to_jsonb(link));
       end if;
    end if;

  end loop;

  if tg_op = 'DELETE' then return old; end if;

  new := jsonb_populate_record(new,rn);
  return new;   
end
$_X$;

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

---------------------------------------------------
-- admin functions
---------------------------------------------------

CREATE FUNCTION dl_chattr(
  dl_schema_name name, 
  dl_table_name name, 
  dl_column_name name, 
  dl_lco dl_lco) 
RETURNS dl_lco
    LANGUAGE plpgsql
    AS $_$
declare
 my_id regclass;
 e text;
 n bigint;
begin
 select into my_id regclass
 from datalink.dl_columns
 where schema_name=$1
   and table_name=$2
   and column_name=$3; 

 if not found then
      raise exception 'Not a datalink column' 
            using errcode = 'DL0101', detail = my_id;
 end if; 

 e := format('select count(%I) from %I.%I where %I is not null limit 1',
   dl_column_name,dl_schema_name,dl_table_name,dl_column_name);
 execute e into n;
 if n > 0 then
   raise exception 'Can''t change link control options; % non-null values present in column "%"',n,dl_column_name;
 end if;
 
 update datalink.dl_optionsdef 
 set control_options = $4
 where schema_name=$1
   and table_name=$2
   and column_name=$3;

 if not found then
  insert into datalink.dl_optionsdef (schema_name,table_name,column_name,control_options)
  values ($1,$2,$3,$4);
 end if;

 return $4;
end;
$_$;

COMMENT ON FUNCTION dl_chattr(dl_schema_name name, dl_table_name name, dl_columnt_name name, dl_lco dl_lco) 
IS 'Set attributes for datalink column (buggy)';


grant usage on schema datalink to public;

