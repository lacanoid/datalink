\pset null _null_

SET client_min_messages = warning;
SET search_path=datalink;

select dlvalue('http://www.ljudmila.org');
select dlvalue('http://www.ljudmila.org','URL','Example datalink');
select dlvalue('/tmp','FS','Example file datalink');

