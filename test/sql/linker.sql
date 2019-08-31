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
 where regclass='sample_datalinks6'::regclass and column_name='link';

update datalink.column_options
   set link_control='FILE', integrity='ALL'
 where regclass='sample_datalinks6'::regclass and column_name='link2';

insert into sample_datalinks6 (link)
values (dlvalue('/tmp/CHANGELOG.md','FS','Sample file datalink 1'));

update sample_datalinks6 set link2 = link;
update sample_datalinks6 set link = link2;
update sample_datalinks6 set link2 = null;

truncate sample_datalinks6;
insert into sample_datalinks6 (link)
values (dlvalue('/tmp/CHANGELOG.md','FS','Sample file datalink 2'));

update sample_datalinks6
   set link = dlnewcopy(link);

update sample_datalinks6 set link2 = link, link = null;
update sample_datalinks6 set link2 = null, link = link2;


