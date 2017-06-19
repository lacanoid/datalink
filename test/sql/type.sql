\pset null _null_

SET client_min_messages = warning;
SET search_path=datalink;

select dlvalue('http://www.ljudmila.org');
select dlvalue('http://www.ljudmila.org','URL','Example datalink');
select dlvalue('/tmp','FS','Example file datalink');

select dlcomment(dlvalue('http://www.ljudmila.org','URL','Example datalink'));
select dlurlcomplete(dlvalue('http://www.ljudmila.org','URL','Example datalink'));
select dlurlcompleteonly(dlvalue('http://www.ljudmila.org','URL','Example datalink'));

select dlnewcopy(dlvalue('http://www.ljudmila.org'),0);
select (dlnewcopy(dlvalue('http://www.ljudmila.org'),1)).token is not null;

select dlpreviouscopy(dlvalue('http://www.ljudmila.org'),0);
select (dlpreviouscopy(dlvalue('http://www.ljudmila.org'),1)).token is not null;

