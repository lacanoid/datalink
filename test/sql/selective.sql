\pset null _null_
\set VERBOSITY default
\set CONTEXT never

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks2 (
  id serial,
  link datalink
);

update datalink.columns
   set link_control='FILE', integrity='SELECTIVE'
 where table_name='sample_datalinks2' and column_name='link';

select regclass,column_name,dlco.*
  from datalink.dl_columns left join datalink.link_control_options dlco using (lco);

insert into sample_datalinks2 (link)
values (dlvalue('/etc/','FS','Sample file datalink'));

insert into sample_datalinks2 (link)
values (dlvalue('file:///foo+bar/no_file','URL','Sample file datalink 2'));

update datalink.columns
   set link_control='FILE', integrity='SELECTIVE'
 where table_name='sample_datalinks2' and column_name='link';

insert into sample_datalinks2 (link)
values (dlvalue('https://www.wikipedia.org/','URL','Sample HTTPS datalink'));

insert into sample_datalinks2 (link)
values (dlvalue('http://blah','URL','Broken datalink'));

select dlurlcomplete(link), link::jsonb->>'b' is not null as has_token from sample_datalinks2;

create table sample_datalinks3 as 
select *
  from sample_datalinks;

update datalink.columns
   set link_control='FILE', integrity='SELECTIVE'
 where table_name='sample_datalinks3' and column_name='link';

delete from sample_datalinks3 where dllinktype(link)='FS';


-- test domains
create domain file datalink;
create domain rfile datalink(1);
create domain efile datalink(2);
create table efiles0 ( file file );
create table efiles1 ( file rfile );
create table efiles2 ( file efile );

insert into efiles1 values (dlvalue('https://www.wikipedia.org/','URL','Sample HTTPS datalink'));
insert into efiles1 values (dlvalue('http://blahXXXX','URL','Broken datalink'));
