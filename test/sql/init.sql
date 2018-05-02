create extension datalink cascade;

set search_path=datalink;

\dx datalink

select oid::regprocedure,obj_description(oid) from pg_proc p 
 where pronamespace = 'datalink'::regnamespace
 order by obj_description(oid) is null, cast(oid::regprocedure as text) collate "C";

