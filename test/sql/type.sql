\pset null _null_

SET client_min_messages = warning;
SET search_path=datalink;

select dlvalue('http://www.ljudmila.org');
select dlvalue('http://www.ljudmila.org','URL','Example datalink');
select dlvalue('/tmp','FS','Example file datalink');
select dlvalue('file:///tmp','URL','Example file datalink #2');

select dlcomment(dlvalue('http://www.ljudmila.org','URL','Example datalink'));
select dlurlcomplete(dlvalue('http://www.ljudmila.org','URL','Example datalink'));
select dlurlcompleteonly(dlvalue('http://www.ljudmila.org','URL','Example datalink'));

select dlnewcopy(dlvalue('http://www.ljudmila.org'),0);
select (dlnewcopy(dlvalue('http://www.ljudmila.org'),1))->>'token' is not null;

select dlpreviouscopy(dlvalue('http://www.ljudmila.org'),0);
select (dlpreviouscopy(dlvalue('http://www.ljudmila.org'),1))->>'token' is not null;

select dlpreviouscopy(dlvalue('/tmp/file1','FS'),0);
select key,case when key is distinct from 'token' then value end as value
  from jsonb_each(dlpreviouscopy(dlvalue('/tmp/file1','FS','Previous copy'),1));
select dlpreviouscopy(dlvalue('/tmp/file1#e5ed6a45-dc2f-42d2-a746-10c368677121','FS'),0);
select dlpreviouscopy(dlvalue('/tmp/file1#e5ed6a45-dc2f-42d2-a746-10c368677121','FS'),1);
select dlpreviouscopy('file:///tmp/file1#e5ed6a45-dc2f-42d2-a746-10c368677121',1);
select dlpreviouscopy('file:///tmp/file1#krneki',1);

select dl_lco(link_control=>'FILE');
select dl_lco(link_control=>'FILE',integrity=>'ALL',read_access=>'DB',write_access=>'BLOCKED');
select * from link_control_options(dl_lco(link_control=>'NO'));
select * from link_control_options(dl_lco(link_control=>'FILE',integrity=>'SELECTIVE'));
select * from link_control_options(dl_lco(link_control=>'FILE',integrity=>'ALL'));
select * from link_control_options(dl_lco(link_control=>'FILE',integrity=>'ALL',
					  read_access=>'DB',write_access=>'BLOCKED',
					  recovery=>'YES',on_unlink=>'DELETE'));
select * from link_control_options(dl_lco(link_control=>'FILE',integrity=>'ALL',
					  read_access=>'DB',write_access=>'BLOCKED',
					  recovery=>'YES',on_unlink=>'RESTORE'));

select dlurlserver(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));
select dlurlscheme(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));

select dlurlpath(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));
select dlurlpathonly(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));

select dllinktype(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));
select dllinktype(dlvalue('/etc/passwd','FS'));
