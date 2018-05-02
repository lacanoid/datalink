create extension datalink cascade;

set search_path=datalink;

\dx datalink

select p.pronamespace::regnamespace,oid::regprocedure,obj_description(oid) from pg_proc p 
 where pronamespace = 'datalink'::regnamespace
    or (pronamespace = 'pg_catalog'::regnamespace 
        and proname like 'dl%'
        and obj_description(oid) like 'SQL/MED%')
 order by 1, obj_description(oid) is null, cast(oid::regprocedure as text) collate "C";

