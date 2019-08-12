\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks4 (
  id serial,
  link datalink
);

select dl_chattr('public','sample_datalinks4','link', dl_lco(link_control=>'FILE',integrity=>'ALL'));

insert into sample_datalinks4 (link)
values (dlvalue('/etc/passwd','FS','Sample file datalink 1'));

insert into sample_datalinks4 (link)
values (dlvalue('/etc/issue','FS','Sample file datalink 2'));

insert into sample_datalinks4 (link)
values (dlvalue('/etc/issue1','FS','Sample file datalink 3'));

insert into sample_datalinks4 (link)
values (dlvalue('/etc/hosts','FS','Sample file datalink 4'));

insert into sample_datalinks3 (url,link) select dlurlcompleteonly(link),link from sample_datalinks4;

select state,regclass,attname,path
  from datalink.dl_linked_files;

delete from sample_datalinks4
 where link->>'token' =
(select token::text
  from datalink.dl_linked_files
 order by txid limit 1);

select state,regclass,attname,path
  from datalink.dl_linked_files;

create table sample_datalinks5 (
  id serial,
  link datalink
);

select dl_chattr('public','sample_datalinks5','link', dl_lco(link_control=>'FILE',integrity=>'ALL'));

insert into sample_datalinks5 (link)
values (dlvalue('/etc/passwd','FS','Sample file datalink'));

insert into sample_datalinks5 (link)
values (dlvalue('/etc/issue','FS','Sample file datalink'));

select state,regclass,attname,path
  from datalink.dl_linked_files;

drop table sample_datalinks5;

truncate sample_datalinks4;

insert into sample_datalinks4 (link)
select link
  from sample_datalinks3
 where dllinktype(link)='FS';

alter table sample_datalinks4
 drop column link;

