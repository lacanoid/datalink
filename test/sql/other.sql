\pset null _null_

SET client_min_messages = warning;
SET search_path = public,datalink;

create table sample_urls (
  id serial,
  url text
);

insert into sample_urls (url)
values 
  ('http://www.ljudmila.org'),
  ('https://www.guthub.org'),
  ('file:///tmp/a');

select * from sample_urls;

create table sample_datalinks (
  url text,
  link datalink
);

select * from dl_triggers;

