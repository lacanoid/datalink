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
  ('file:///tmp/a');

select * from sample_urls;

create table sample_datalinks (
  url text,
  link datalink
);

select * from dl_triggers;

select column_name,control_options FROM datalink.dl_columns;

insert into sample_datalinks (link)
values (dlvalue('http://www.archive.org','URL','Sample datalink'));

insert into sample_datalinks (url,link)
select url,dlvalue(url) 
  from sample_urls;

update sample_datalinks
   set link = null
 where url like 'file:%';

delete from sample_datalinks
 where url like 'https:%';
 
 
