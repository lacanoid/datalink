create table cu ( name text, url text );
insert into cu (url)
values
  ('file:///tmp/file1.txt'),
  ('file:/tmp/file1.txt'),
  ('file://localhost/tmp/file1.txt'),
  ('http://www.ljudmila.org/robots.txt'),
  ('http://www.ljudmila.org/robots2.txt'),
  ('data:,Hello%2C%20World%21'),
  ('data:text/plain;base64,SGVsbG8sIFdvcmxkIQ=='),
  ('data:text/html,%3Ch1%3EHello%2C%20World%21%3C%2Fh1%3E'),
  ('data:text/html,%3Cscript%3Ealert%28%27hi%27%29%3B%3C%2Fscript%3E'),
  ('file:/var/www/datalink/installcheck/utf8.txt'),
  ('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt')
;
-- select ok,rc,url,size,content_type,error from ( select (datalink.curl_perform(null,url)).* from cu ) as c;
-- test curl
select body,size,content_type from datalink.curl_perform(null,'data:,Hello%2C%20World%21');
select body,size,content_type from datalink.curl_perform(null,'data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==');
select body,size,content_type from datalink.curl_perform(null,'data:text/html,%3Ch1%3EHello%2C%20World%21%3C%2Fh1%3E');
select body,size,content_type from datalink.curl_perform(null,'data:text/html,%3Cscript%3Ealert%28%27hi%27%29%3B%3C%2Fscript%3E');

create server zala foreign data wrapper postgres_fdw options (dbname 'contrib_regression');
create user mapping for current_user server zala;
select url,ok,rc,error from datalink.curl_get('file://zala/etc/issue');
select url,ok,rc,error from datalink.curl_perform(null,'file://zala/etc/issue');
select body,ok,size,content_type,error from datalink.curl_perform(null,'file://zala/var/www/datalink/installcheck/utf8.txt');
drop user mapping for current_user server zala;
drop server zala;

select body,ok,size,content_type,error from datalink.curl_perform(null,'file:/var/www/datalink/installcheck/utf8.txt');

select body,ok,size,content_type,error from datalink.curl_perform(null,'https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt');

