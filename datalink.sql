--
--  datalink
--  version 0.1 lacanoid@ljudmila.org
--
---------------------------------------------------

SET client_min_messages = warning;

---------------------------------------------------

---------------------------------------------------
-- datalink type
---------------------------------------------------

CREATE TYPE dl_linktype AS ENUM ('URL','FS');
CREATE TYPE datalink AS (
	url text,
	token uuid,
	comment text
);

CREATE FUNCTION dlvalue(uri text, linktype dl_linktype DEFAULT 'URL', comment text DEFAULT NULL) 
RETURNS datalink
    LANGUAGE plpgsql IMMUTABLE
    AS $$
begin
 if linktype = 'FS' then
  uri := 'file://'||uri;
 end if;
 return row(uri,null::uuid,comment);
end
$$;

---------------------------------------------------
-- link control options
---------------------------------------------------

CREATE TYPE dl_integrity AS ENUM (
    'NONE','SELECTIVE','ALL'
);
CREATE TYPE dl_link_control AS ENUM (
    'NO','FILE'
);
CREATE TYPE dl_on_unlink AS ENUM (
    'NONE','RESTORE','DELETE'
);
CREATE TYPE dl_read_access AS ENUM (
    'FS','DB'
);
CREATE TYPE dl_write_access AS ENUM (
    'FS','BLOCKED',
    'ADMIN NOT REQUIRING TOKEN FOR UPDATE',
    'ADMIN REQUIRING TOKEN FOR UPDATE'
);
CREATE TYPE dl_recovery AS ENUM (
    'NO','YES'
);
CREATE TYPE dl_lcp AS (
	link_control dl_link_control,
	integrity dl_integrity,
	read_access dl_read_access,
	write_access dl_write_access,
	recovery dl_recovery,
	on_unlink dl_on_unlink
);
comment on type dl_lcp is 'Datalink Link Control Options';

---------------------------------------------------
-- event triggers
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
CREATE DOMAIN dl_options AS integer;
CREATE TABLE dl_optionsdef (
    schema_name name NOT NULL,
    table_name name NOT NULL,
    column_name name NOT NULL,
    control_options dl_options DEFAULT 0 NOT NULL
);
COMMENT ON TABLE dl_optionsdef 
IS 'Current link control options; this should really go to pg_attribute.atttypmod';
ALTER TABLE ONLY dl_optionsdef
    ADD CONSTRAINT dl_optionsdef_pkey PRIMARY KEY (schema_name, table_name, column_name);

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
         (tn.nspname = 'datalink'::name) AND (t.typname = 'datalink'::name) AND
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
               || ' FOR EACH ROW EXECUTE PROCEDURE datalink.dl_trigger()'::text, ''::text) 
    else ''
    end AS sql_advice
   FROM datalink.dl_triggers
$$;

---------------------------------------------------

CREATE FUNCTION dl_event_trigger() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
declare
 obj record;
begin
 if tg_tag in ('CREATE TABLE','ALTER TABLE') 
 then
--   RAISE NOTICE 'DATALINK % trigger: %', tg_event, tg_tag;
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

