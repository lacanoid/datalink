\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_urls (
  id serial,
  url text
);

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

create table sample_datalinks (
  url text,
  link datalink
);

--select * from dl_triggers;
--select column_name,lco FROM datalink.dl_columns;
--select * from datalink.column_options;

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
 
