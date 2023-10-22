\pset null _null_
\set VERBOSITY default
\set CONTEXT never

SET client_min_messages = notice;
SET search_path = public,datalink;

create table sample_datalinks6 (
  id serial,
  link datalink,
  link2 datalink
);

update datalink.columns
   set link_control='FILE', integrity='ALL',
       read_access='DB', write_access='TOKEN',
       recovery='YES', on_unlink='RESTORE'
 where table_name='sample_datalinks6' and column_name='link';

update datalink.columns
   set link_control='FILE', integrity='ALL'
 where table_name='sample_datalinks6' and column_name='link2';

insert into sample_datalinks6 (link)
values (dlvalue('/var/www/datalink/CHANGELOG.md','FS','Sample file datalink 1'));

update sample_datalinks6 set link2 = link;
update sample_datalinks6 set link = link2;
update sample_datalinks6 set link2 = null;

set client_min_messages=warning;
drop role if exists datalink_test_user_123;
create role datalink_test_user_123;
set role datalink_test_user_123;
--select length(datalink.read_text(dlurlpath(link)) > 0 from sample_datalinks6;
--select length(datalink.read_text('/var/www/datalink/CHANGELOG.md')) > 0;
reset role;
drop role datalink_test_user_123;
set client_min_messages=notice;

truncate sample_datalinks6;
insert into sample_datalinks6 (link)
values (dlvalue('/var/www/datalink/CHANGELOG.md','FS','Sample file datalink 2'));
insert into sample_datalinks6 (link)
values (dlvalue('http://www.debian.org/tmp/CHANGELOG.md',null,'Weblink'));

select regexp_replace(dlurlpath(link),'[a-z0-9\-]{10,}','xxxx','g') as dlurlpath1
  from sample_datalinks6;
select dlurlpathonly(link) from sample_datalinks6;

update sample_datalinks6
   set link = dlnewcopy(link);

update sample_datalinks6 set link2 = link, link = null;
update sample_datalinks6 set link2 = null, link = link2;

create table sample_datalinks7 as 
select * 
  from sample_datalinks6;

truncate sample_datalinks6;

insert into sample_datalinks6 (link) values (dlvalue('/var/www/datalink/CHANGELOG.md'));
select link-'b' from sample_datalinks6; truncate sample_datalinks6;

insert into my_table2
select dlvalue(filename)
  from sample_files
 where filename like '%.txt'
   and not (filename like '%X%' or filename like '%3.txt');

truncate my_table2;

-- test for foreign servers
select * from datalink.curl_get('file://zala/etc/issue');
create extension dblink;
select * from datalink.curl_get('file://zala/etc/issue');
create extension postgres_fdw;
create server zala foreign data wrapper postgres_fdw options (dbname 'contrib_regression');
select * from datalink.curl_get('file://zala/etc/issue');
select * from datalink.curl_get('file://tiha/etc/issue');
create user mapping for current_user server zala;
select url,ok,rc,error from datalink.curl_get('file://zala/etc/issue');
select url,ok,rc,error from datalink.curl_get('file://zala/etc/issueXXXXX');

-- test directories
update datalink.directory
   set dirname='www', 
       dirowner=current_role::regrole,
       dirurl='http://localhost/datalink/'
 where dirpath='/var/www/datalink/';
select dlvalue('hello.txt','www');
select dlvalue('','www');
select dlvalue(NULL,'www');

select dlvalue('http://localhost/datalink/CHANGELOG.md');
select dlurlcomplete(dlvalue('http://localhost/datalink/CHANGELOG.md'));
select dlurlcompleteonly(dlvalue('http://localhost/datalink/CHANGELOG.md'));

select dlvalue('http://localhost/datalinkxxx/CHANGELOG.md');
select dlurlcomplete(dlvalue('http://localhost/datalinkxxx/CHANGELOG.md'));
select dlurlcompleteonly(dlvalue('http://localhost/datalinkxxx/CHANGELOG.md'));

insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','PUBLIC','SELECT');
insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','PUBLIC','REFERENCES');

begin;
create role dl_access_test;

select dirpath,privilege_type,grantee from datalink.access;
insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','dl_access_test','UPDATE');
insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','PUBLIC','REFERENCES');
insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','dl_access_test','SELECT');
select dirpath,privilege_type,grantee from datalink.access;
delete from datalink.access where grantee = 'dl_access_test';
select dirpath,privilege_type,grantee from datalink.access;
delete from datalink.access where grantee = 'PUBLIC';
select dirpath,privilege_type,grantee from datalink.access;
insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','dl_access_test','DELETE');
select dirpath,privilege_type,grantee from datalink.access;

drop role dl_access_test;
rollback;

insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink/','PUBLIC','KIKI');
insert into datalink.access (dirpath,grantee,privilege_type) values ('/var/www/datalink_xxx/','PUBLIC','REFERENCES');

select dirpath,privilege_type,grantee from datalink.access;
