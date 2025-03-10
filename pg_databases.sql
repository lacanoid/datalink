BEGIN;

SET search_path TO datalink;

CREATE OR REPLACE FUNCTION pg_clusters(
  OUT version text, OUT cluster text, OUT port integer, OUT running boolean, OUT recovery boolean,
  OUT buffers text, OUT pgdata text, OUT logfile text)
 RETURNS SETOF record
 LANGUAGE plperlu
 COST 1000 ROWS 10
AS $function$
# Get Postgres cluster information
use JSON;
my $j=`pg_lsclusters -j`;
my $c=decode_json $j;
for my $i (@$c) { 
        my $h = { 
                version=>$i->{version}, 
                cluster=>$i->{cluster}, 
                logfile=>$i->{logfile},
                pgdata=>$i->{pgdata},
                port=>$i->{port}+0,
                running=>$i->{running}+0,
                recovery=>$i->{recovery}+0,
                buffers=>$i->{config}{shared_buffers}
        };
        return_next($h); 
}
return undef;
$function$;

GRANT EXECUTE ON FUNCTION pg_clusters() TO PUBLIC;

CREATE OR REPLACE VIEW pg_clusters AS
 SELECT pg_clusters.version,
    pg_clusters.cluster,
    pg_clusters.port,
    pg_clusters.running,
    pg_clusters.recovery,
    pg_clusters.buffers,
    pg_clusters.pgdata,
    pg_clusters.logfile
   FROM pg_clusters() pg_clusters(version, cluster, port, running, recovery, buffers, pgdata, logfile);

GRANT SELECT ON pg_clusters TO PUBLIC;

CREATE OR REPLACE VIEW pg_databases AS
 SELECT dbs.cluster,
    dbs.port,
    dbs.name,
    dbs.owner,
    dbs.connections,
    dbs.size
   FROM pg_clusters() c(version, cluster, port, running, recovery, buffers, pgdata, logfile),
    LATERAL public.dblink('port='::text || c.port, '
with dat as (
select d.datname::text as name,
       datdba::regrole::text as owner,
       count(a)::int as connections
  from pg_database d
  left join pg_catalog.pg_stat_activity a on (a.datid=d.oid)
 where datallowconn
   and a.pid is distinct from pg_backend_pid()
 group by 1,2 
)
select current_setting(''cluster_name'') as cluster,
       current_setting(''port'')::int as port,
       *,
       pg_database_size(name)::bigint as size
  from dat order by 1,2
'::text) dbs(cluster text, port integer, name text, owner text, connections integer, size bigint);

GRANT SELECT ON pg_databases TO PUBLIC;

END;
