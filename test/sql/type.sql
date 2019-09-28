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

\x
with a as (
  select 'http://ziga:pass@www.ljudmila.org:8888/foo/bar/baz.qux?a=1&b=2#x123' as uri
)
select
 uri,
 uri_get(uri,'scheme') as scheme,
 uri_get(uri,'authority') as authority,
 uri_get(uri,'userinfo') as userinfo,
 uri_get(uri,'host') as host,
 uri_get(uri,'port') as port,
 uri_get(uri,'host_port') as host_port,
 uri_get(uri,'domain') as domain,
 uri_get(uri,'path') as path,
 uri_get(uri,'dirname') as dirname,
 uri_get(uri,'basename') as basename,
 uri_get(uri,'path_query') as path_query,
 uri_get(uri,'query') as query,
 uri_get(uri,'query_form') as query_form,
 uri_get(uri,'query_keywords') as query_keywords,
 uri_get(uri,'fragment') as fragment,
 uri_get(uri,'token') as token,
 uri_get(uri,'canonical') as canonical
from a;

 
