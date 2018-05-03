create extension datalink cascade;

set search_path=datalink;

\dx datalink

select p.pronamespace::regnamespace,p.oid::regprocedure,l.lanname,obj_description(p.oid) 
  from pg_proc p 
  join pg_language l on p.prolang=l.oid
 where pronamespace = 'datalink'::regnamespace
    or (pronamespace = 'pg_catalog'::regnamespace 
        and proname like 'dl%'
        and obj_description(p.oid) like 'SQL/MED%')
 order by 1, obj_description(p.oid) is null, cast(p.oid::regprocedure as text) collate "C";

