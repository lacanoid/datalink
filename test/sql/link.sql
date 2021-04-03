\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks4 (
  id serial,
  link datalink
);

-- select dl_chattr('sample_datalinks4','link', dl_lco(link_control=>'FILE',integrity=>'ALL'));
update datalink.column_options
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks4' and column_name='link';

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

-- select dl_chattr('sample_datalinks5','link', dl_lco(link_control=>'FILE',integrity=>'ALL'));
update datalink.column_options
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks5' and column_name='link';

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

truncate sample_datalinks4;
alter table sample_datalinks4
 add column link datalink;

alter table sample_datalinks4
 add column link2 datalink;
-- select dl_chattr('sample_datalinks4','link2',dl_lco(link_control=>'FILE',integrity=>'ALL'));
update datalink.column_options
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks4' and column_name='link2';

insert into sample_datalinks4 (link)
select link
  from sample_datalinks3
 where dllinktype(link)='FS';

update sample_datalinks4 set link2 = link;
update sample_datalinks4 set link = link2;
update sample_datalinks4 set link2 = null;

update datalink.column_options
   set link_control='FILE', integrity='SELECTIVE', recovery='YES'
 where table_name='sample_datalinks4' and column_name='link2';

select * from column_options;
alter table sample_datalinks4 rename link2 to link3;
select * from column_options where table_name='sample_datalinks4';

update sample_datalinks4 set link3 = link;

select * from datalink.linked_files where regclass='sample_datalinks4'::regclass;
alter table sample_datalinks4 rename link3 to link4;
select * from column_options where table_name='sample_datalinks4';
select * from datalink.linked_files where regclass='sample_datalinks4'::regclass;

