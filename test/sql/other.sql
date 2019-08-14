\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks2 (
  id serial,
  link datalink
);

select dl_chattr('sample_datalinks2','link', dl_lco(link_control=>'FILE',integrity=>'SELECTIVE'));

select regclass,column_name,dlco.*
  from datalink.dl_columns left join datalink.dl_link_control_options dlco using (lco);
/*
insert into sample_datalinks2 (link)
values (dlvalue('http://en.wikipedia.org','URL','Sample datalink'));
*/
insert into sample_datalinks2 (link)
values (dlvalue('/etc/','FS','Sample file datalink'));

insert into sample_datalinks2 (link)
values (dlvalue('file:///foo+bar/no_file','URL','Sample file datalink 2'));

select dl_chattr('sample_datalinks2','link', dl_lco(link_control=>'FILE',integrity=>'SELECTIVE'));

insert into sample_datalinks2 (link)
values (dlvalue('https://www.debian.org','URL','Sample HTTPS datalink'));

insert into sample_datalinks2 (link)
values (dlvalue('http://blah','URL','Broken datalink'));

select dlurlcomplete(link), (link)->>'token' is not null as has_token from sample_datalinks2;

create table sample_datalinks3
    as 
select *
  from sample_datalinks;

select dl_chattr('sample_datalinks3','link', dl_lco(link_control=>'FILE',integrity=>'SELECTIVE'));

delete from sample_datalinks3 where dllinktype(link)='FS';
