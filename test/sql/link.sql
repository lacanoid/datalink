\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks4 (
  id serial,
  link datalink
);

-- select dl_chattr('sample_datalinks4','link', dl_lco(link_control=>'FILE',integrity=>'ALL'));
update datalink.columns
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks4' and column_name='link';

insert into sample_datalinks4 (link)
values (dlvalue('/etc/passwd','FS','Sample file datalink 1'));

insert into sample_datalinks4 (link)
values (dlvalue('/var/www/datalink/test1.txt','FS','Sample file datalink 2'));

insert into sample_datalinks4 (link)
values (dlvalue('/var/www/datalink/test3.txt','FS','Sample file datalink 3'));

insert into sample_datalinks4 (link)
values (dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced','FS','Sample file datalink 3b'));

insert into sample_datalinks4 (link)
values (dlvalue('/etc/hosts','FS','Sample file datalink 4'));

insert into sample_datalinks4 (link)
values (dlvalue('/var/www/datalink/test2.txt','FS','Sample file datalink 4'));

insert into sample_datalinks3 (url,link) select dlurlcompleteonly(link),link from sample_datalinks4;

select state,regclass,attname,path
  from datalink.linked_files;

delete from sample_datalinks4
 where link->>'token' =
(select token::text
  from datalink.dl_linked_files
 order by txid limit 1);

select state,regclass,attname,path
  from datalink.linked_files;

create table sample_datalinks5 (
  id serial,
  link datalink
);

-- select dl_chattr('sample_datalinks5','link', dl_lco(link_control=>'FILE',integrity=>'ALL'));
update datalink.columns
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks5' and column_name='link';

insert into sample_datalinks5 (link)
values (dlvalue('/etc/passwd','FS','Sample file datalink'));

insert into sample_datalinks5 (link)
values (dlvalue('/var/www/datalink/test1.txt','FS','Sample file datalink'));

select state,regclass,attname,path
  from datalink.linked_files;

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
update datalink.columns
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks4' and column_name='link2';

insert into sample_datalinks4 (link)
select link
  from sample_datalinks3
 where dllinktype(link)='FS';

update sample_datalinks4 set link2 = link;
update sample_datalinks4 set link = link2;
update sample_datalinks4 set link2 = null;

update datalink.columns
   set link_control='FILE', integrity='SELECTIVE', recovery='YES'
 where table_name='sample_datalinks4' and column_name='link2';

select * from columns;
alter table sample_datalinks4 rename link2 to link3;
select * from columns where table_name='sample_datalinks4';

update sample_datalinks4 set link3 = link;

select path,state,read_access,write_access,recovery,on_unlink,regclass,attname,err from datalink.linked_files where regclass='sample_datalinks4'::regclass;
alter table sample_datalinks4 rename link3 to link4;
select * from columns where table_name='sample_datalinks4';
select path,state,read_access,write_access,recovery,on_unlink,regclass,attname,err from datalink.linked_files where regclass='sample_datalinks4'::regclass;

alter table sample_datalinks4 drop column link4;

create table my_table(link datalink);
update datalink.columns set integrity='SELECTIVE' where table_name='my_table';
create table my_table2(link datalink);
update datalink.columns set integrity='ALL' where table_name='my_table2';
create table my_table3(link datalink);
update datalink.columns set integrity='ALL',write_access='BLOCKED' where table_name='my_table3';
create table my_table4(link datalink);
update datalink.columns set integrity='ALL',write_access='BLOCKED',read_access='DB',on_unlink='DELETE' where table_name='my_table4';
select * from datalink.columns order by table_name;
