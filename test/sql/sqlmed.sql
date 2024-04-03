\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_urls (
  id serial,
  url text
);

select dlurlserver(dlvalue('file:///etc/issue'));
select dlurlserver(dlvalue('file://server1/etc/issue'));

select dlvalue('/tmp/test-_=!@$^&()[]{}#?','FS');
select dlurlpath(dlvalue('/tmp/test-_=!@$^&()[]{}#?','FS'));
select dlurlcomplete(dlvalue('/tmp/test-_=!@$^&()[]{}#?','FS'));

insert into sample_urls (url)
values 
  ('http://www.mozilla.org');

insert into sample_urls (url)
values 
  ('http://www.ljudmila.org'),
  ('https://www.github.org'),
  ('file:///tmp/a'),
  ('http://www.debian.org/');

select * from sample_urls;

---------------------
create table sample_files (
  id serial,
  filename datalink.file_path
);

insert into sample_files (filename)
values 
  ('/var/www/datalink/test1.txt'),
  ('/var/www/datalink/test2.txt'),
  ('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),
  ('/var/www/datalink/testX.txt'),
  ('/var/www/datalink/CHANGELOG.md');

select *,dlvalue(filename) from sample_files;

---------------------
create table sample_datalinks (
  url text,
  link datalink
);

--select * from dl_triggers;
--select column_name,lco FROM datalink.dl_columns;
--select * from datalink.columns;

insert into sample_datalinks (link)
values (dlvalue('http://www.archive.org','URL','Sample datalink'));

insert into sample_datalinks (link)
values (dlvalue('http://guthub.org','URL','Another sample datalink'));

insert into sample_datalinks (url,link)
select url,dlvalue(url) 
  from sample_urls;

update sample_datalinks
   set link = null
 where url like 'file:%';

update sample_datalinks
   set link = null
 where url like '%debian.org%';

delete from sample_datalinks
 where url like 'https:%';
 
update sample_datalinks
   set link = dlvalue(url)
 where link is null and url is not null;

-- check for some exceptions from the SQL standard
create table med (link datalink(2));

-- 15.2 Effect of inserting tables into base tables

-- case 1.a.1 referenced file does not exist
insert into med (link) values (dlvalue('file:///var/www/datalink/non_existant_file')); -- err
-- 
-- case 1.b.1 invalid datalink construction
insert into med (link) values (dlpreviouscopy('file:///var/www/datalink/test1.txt')); -- err
insert into med (link) values (dlnewcopy('file:///var/www/datalink/test1.txt')); -- err
insert into med (link) values (dlvalue('file:///var/www/datalink/test1.txt')); -- ok
-- 
-- case 1.b.2 external file already linked
insert into med (link) values (dlvalue('file:///var/www/datalink/test1.txt')); -- err
-- 
-- 15.3 Effect of replacing rows in base tables
update med set link = dlvalue('file:///var/www/datalink/test2.txt'); -- ok
--
-- case 1.b.i.1 referenced file does not exist
update med set link = dlvalue('file:///var/www/datalink/non_existant_file'); -- err
--
-- case 1.b.ii.1 external file already linked
insert into med (link) values (dlvalue('file:///var/www/datalink/test1.txt')); -- ok
update med set link = dlvalue('file:///var/www/datalink/test4.txt'); -- err
--
-- case 1.b.ii.2.A.I invalid write token
delete from med;
update datalink.columns set read_access='DB',write_access='TOKEN' where table_name='med';
insert into med (link) values (dlvalue('file:///var/www/datalink/test1.txt')); -- ok
update med set link = dlnewcopy('file:///var/www/datalink/test1.txt'); -- err
--
-- case 1.b.ii.2.B invalid write permission for update
update datalink.columns set read_access='DB',write_access='BLOCKED' where table_name='med';
update med set link = dlnewcopy('file:///var/www/datalink/test2.txt'); -- err
--
-- case 1.b.ii.2.C referenced file not valid
update datalink.columns set read_access='DB',write_access='ADMIN' where table_name='med';
update med set link = dlnewcopy('file:///var/www/datalink/test2.txt'); -- err
update med set link = dlvalue('file:///var/www/datalink/test2.txt'); -- ok
update med set link = dlnewcopy('file:///var/www/datalink/test2.txt'); -- ok

drop table med;
