\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_urls (
  id serial,
  url text
);

select dlvalue('/tmp/test-_=!@$%^&*()[]{}#?','FS');
select dlurlpath(dlvalue('/tmp/test-_=!@$%^&*()[]{}#?','FS'));
select dlurlcomplete(dlvalue('/tmp/test-_=!@$%^&*()[]{}#?','FS'));

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
  filename text
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
 
