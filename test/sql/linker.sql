\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks6 (
  id serial,
  link datalink,
  link2 datalink
);

update datalink.column_options
   set link_control='FILE', integrity='ALL',
       read_access='FS', write_access='BLOCKED',
       recovery='YES', on_unlink='RESTORE'
 where table_name='sample_datalinks6' and column_name='link';

update datalink.column_options
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks6' and column_name='link2';

insert into sample_datalinks6 (link)
values (dlvalue('/tmp/CHANGELOG.md','FS','Sample file datalink 1'));

update sample_datalinks6 set link2 = link;
update sample_datalinks6 set link = link2;
update sample_datalinks6 set link2 = null;

truncate sample_datalinks6;
insert into sample_datalinks6 (link)
values (dlvalue('/tmp/CHANGELOG.md','FS','Sample file datalink 2'));

select regexp_replace(dlurlpath(link),'[a-z0-9\-]{10,}','xxx','g') as dlurlpath1
  from sample_datalinks6;
select dlurlpathonly(link) from sample_datalinks6;

update sample_datalinks6
   set link = dlnewcopy(link);

update sample_datalinks6 set link2 = link, link = null;
update sample_datalinks6 set link2 = null, link = link2;

create table sample_datalinks7 as 
select * 
  from sample_datalinks6;

truncate sample_datalinks6;


