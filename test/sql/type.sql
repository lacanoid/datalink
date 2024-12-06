\pset null _null_

SET client_min_messages = warning;
SET search_path=public;

select dlvalue(null);
select dlvalue('');
select dlvalue('foo');
select dlvalue('http://www.ljudmila.org/');
select dlvalue('http://www.ljudmila.org/','URL','Example datalink');
select dlvalue('HTTP://WWW.ljudmila.org/A/B/c','URL');
select dlvalue('/tmp','FS','Example file datalink');
select dlvalue('file:///tmp','URL','Example file datalink #2');
select dlvalue('file:///tmp/a/b/c/d/../../x/y','URL','Example file datalink #3');

select dlvalue('favicon.ico',dlvalue('http://www.ljudmila.org/index.html'));
select dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced',dlvalue('/var/www/datalink/'),'Comment');
select dlurlpath(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced',dlvalue('/var/www/datalink/')));
select dlurlpathonly(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced',dlvalue('/var/www/datalink/')));

select dlvalue(null,null,'a comment');

select dlcomment(dlvalue('http://www.ljudmila.org/','URL','Example datalink'));
select dlurlcomplete(dlvalue('http://www.ljudmila.org/','URL','Example datalink'));
select dlurlcompleteonly(dlvalue('http://www.ljudmila.org/','URL','Example datalink'));

select dlpreviouscopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),0);
select dlpreviouscopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),1);
select dlnewcopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),0)::jsonb - 'b';
select dlnewcopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),1)::jsonb - 'b';

select dlpreviouscopy(dlnewcopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),0),0)::jsonb - 'b';
select dlpreviouscopy(dlnewcopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),1),0)::jsonb - 'b';
select dlpreviouscopy(dlnewcopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),0),1)::jsonb - 'b';
select dlpreviouscopy(dlnewcopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),1),1);

select dlnewcopy(dlpreviouscopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),0),0)::jsonb - 'b';
select dlnewcopy(dlpreviouscopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),1),0)::jsonb - 'b';
select dlnewcopy(dlpreviouscopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),0),1)::jsonb - 'b';
select dlnewcopy(dlpreviouscopy(dlvalue('/var/www/datalink/test3.txt#11111111-2222-3333-4444-abecedabeced'),1),1)::jsonb - 'b';

select dlnewcopy(dlvalue('http://www.ljudmila.org/'),0)::jsonb - 'b';
select (dlnewcopy(dlvalue('http://www.ljudmila.org'),1))::jsonb->>'b' is not null;

select dlpreviouscopy(dlvalue('http://www.ljudmila.org/'),0);
select (dlpreviouscopy(dlvalue('http://www.ljudmila.org'),1))::jsonb->>'b' is not null;

select dlpreviouscopy(dlvalue('/tmp/file1','FS'),0);
select key,case when key is distinct from 'b' then value end as value
  from jsonb_each(dlpreviouscopy(dlvalue('/tmp/file1','FS','Previous copy'),1)::jsonb);
select dlpreviouscopy(dlvalue('/tmp/file1#e5ed6a45-dc2f-42d2-a746-10c368677121','FS'),0);
select dlpreviouscopy(dlvalue('/tmp/file1#e5ed6a45-dc2f-42d2-a746-10c368677121','FS'),1);
select dlpreviouscopy('file:///tmp/file1#e5ed6a45-dc2f-42d2-a746-10c368677121',1);
select dlpreviouscopy('file:///tmp/file1#krneki',1);

select dlurlserver(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));
select dlurlscheme(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));

select dlurlserver(dlvalue('HtTp://WwW.LjUDmILA.OrG/Foo/Bar/Baz#123'));
select dlurlscheme(dlvalue('HtTp://WwW.LjUDmILA.OrG/Foo/Bar/Baz#123'));

select dlurlpath(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));
select dlurlpathonly(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));

select dlurlpath(dlvalue('file:///foo/bar/baz#123'));
select dlurlpathonly(dlvalue('file:///foo/bar/baz#123'));

select dllinktype(dlvalue('http://www.ljudmila.org/foo/bar/baz#123'));
select dllinktype(dlvalue('/etc/issue','FS'));

select dlvalue('/etc/züöl');
select dlurlpath(dlvalue('/etc/züöl'));

select dlvalue('/etc/foo[1](2)#3');
select dlurlpath(dlvalue('/etc/foo[1](2)#3'));

select dlvalue('/etc/issue');
select dlvalue('/etc/issue','URL');
select dlvalue('/etc/issue','FS');
select dlvalue('/etc/issue','FILE');
select dlvalue('/etc/issue','foo');
select dllinktype(dlvalue('/etc/issue'));
select dllinktype(dlvalue('/etc/issue','FS'));
select dllinktype(dlvalue('/etc/issue','FILE'));
select dllinktype(dlvalue('/etc/issue','foo'));

select dlvalue('/foo/bar//baz/qux'); -- ERROR
select dlvalue('/foo/bar/../baz/qux'); -- ERROR
select dlvalue('/foo/bar/%/baz/qux'); -- ERROR

SET search_path=datalink;

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

create table bar ( link datalink(123) );
begin;
create table foo ( link datalink(172) );
select * from datalink.columns where table_name in ('foo','bar');
abort;

select dlvalue('robots.txt',dlvalue('http://localhost/index.html',null,'foo'));
select dlvalue('robots.txt',dlvalue('http://localhost/index.html',null,'foo'),'bar');

