create extension datalink cascade;

set search_path=datalink;

select extname as "Name",
       extversion as "Version",
       extnamespace::regnamespace as "Schema",
       obj_description(oid) as "Description" 
  from pg_extension where extname = 'datalink';

select p.pronamespace::regnamespace,p.oid::regprocedure,l.lanname,obj_description(p.oid) 
  from pg_proc p 
  join pg_language l on p.prolang=l.oid
 where pronamespace = 'datalink'::regnamespace
    or (pronamespace = 'pg_catalog'::regnamespace 
        and proname like 'dl%'
        and obj_description(p.oid) like 'SQL/MED%'
        or  obj_description(p.oid) ilike '%datalink%')
 order by 1, obj_description(p.oid) is null,
       cast(p.oid::regprocedure as text) collate "C";

truncate datalink.dl_directory;  -- clean for tests
