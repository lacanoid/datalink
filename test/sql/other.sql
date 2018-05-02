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
  ('http://www.debian.org');

select * from sample_urls;

create table sample_datalinks (
  url text,
  link datalink
) with oids;

select * from dl_triggers;

select column_name,control_options FROM datalink.dl_columns;

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
 
create table sample_datalinks2 (
  id serial,
  link datalink
);

select dl_chattr('public','sample_datalinks2','link', dl_options(link_control=>'FILE'));

select sql_identifier,control_options FROM datalink.dl_columns;

insert into sample_datalinks2 (link)
values (dlvalue('http://www.ljudmila.org','URL','Sample datalink'));

insert into sample_datalinks2 (link)
values (dlvalue('/etc/','FS','Sample file datalink'));

insert into sample_datalinks2 (link)
values (dlvalue('file:///foo+bar/no_file','URL','Sample file datalink 2'));

select (link).url, (link).token is not null as has_token from sample_datalinks2;

