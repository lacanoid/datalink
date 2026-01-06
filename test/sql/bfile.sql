\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

select length(dlvalue('/var/www/datalink/installcheck/utf8.txt')),
       getlength(dlvalue('/var/www/datalink/installcheck/utf8.txt'));

select substr(dlvalue('/var/www/datalink/installcheck/utf8.txt')),
       substr(dlvalue('/var/www/datalink/installcheck/utf8.txt'),12),
       substr(dlvalue('/var/www/datalink/installcheck/utf8.txt'),12,8)
       ;

create domain bfile datalink(2);
create table bfiles ( bfile bfile );

insert into bfiles (bfile) values (dlvalue('test1.txt','www'));
insert into bfiles (bfile) values (dlvalue('installcheck/utf8.txt','www'));
insert into bfiles (bfile) values (dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'));

create domain bfile2 bfile;
create table bfiles2 ( bfile bfile2 );

insert into bfiles2 (bfile) values (dlvalue('test1.txt','www'));
insert into bfiles2 (bfile) values (dlvalue('test4.txt','www'));

select * from datalink.types;

select regclass,column_name,lco,regtype from datalink.dl_columns where regtype <> 'datalink'::regtype order by 1,2;

select substr(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),1,19);

select length(bfile),getlength(bfile),substr(bfile,1,5),filepath(bfile),fileexists(bfile),filegetname(bfile)
  from bfiles;

select read_text(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),1,68);
select read_text(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),48,48);

drop table bfiles;
truncate bfiles2;

-- test text file reads

select read_text('/var/www/datalink/installcheck/utf8.txt');
select read_text('/var/www/datalink/installcheck/utf8.txt',51);
select read_text('/var/www/datalink/installcheck/utf8.txt',51,17);
select read_text(dlvalue('/var/www/datalink/installcheck/utf8.txt'));
select read_text(dlvalue('/var/www/datalink/installcheck/utf8.txt'),51);
select read_text(dlvalue('/var/www/datalink/installcheck/utf8.txt'),51,17);
select read_text(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'));
select read_text(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),51);
select read_text(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),51,17);

select * from read_lines('/var/www/datalink/installcheck/utf8.txt');

-- test binary file reads

select read('/var/www/datalink/installcheck/utf8.txt');
select read('/var/www/datalink/installcheck/utf8.txt',4);
select read('/var/www/datalink/installcheck/utf8.txt',4,10);
select read(dlvalue('/var/www/datalink/installcheck/utf8.txt'));
select read(dlvalue('/var/www/datalink/installcheck/utf8.txt'),4);
select read(dlvalue('/var/www/datalink/installcheck/utf8.txt'),4,10);
select read(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'));
select read(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),4);
select read(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),4,10);

-- test checking for updated files

insert into my_table2 values (dlvalue('/var/www/datalink/installcheck/utf8.txt'));
select datalink.has_updated(link) from my_table2;
\! touch /var/www/datalink/installcheck/utf8.txt
select datalink.has_updated(link) from my_table2;
select datalink.has_updated(link) from my_table2;
select datalink.has_updated(dlvalue('/var/www/datalink/installcheck/utf8.txt'));
update my_table2 set link=dlnewcopy(link);
select datalink.has_updated(link) from my_table2;
select datalink.has_updated(dlvalue('/var/www/datalink/installcheck/utf8.txt'));
truncate my_table2;
select datalink.has_updated(dlvalue('/var/www/datalink/installcheck/utf8.txt'));

select datalink.has_updated('/etc/issue');

-- test link construction types

create table files ( link datalink(2) );
insert into files values (dlvalue('/var/www/datalink/test1.txt'));
update files  set link = dlnewcopy(link);
insert into files values (dlvalue('/var/www/datalink/installcheck/utf8.txt'));
insert into files values (dlreplacecontent('/var/www/datalink/test6.txt','http://www.github.com/robots.txt'));
insert into files values (datalink.write_text(dlvalue('test5.txt','www'),'This is a test file 5'));

select cons,path from datalink.dl_linked_files order by path;

drop table files;

-- test curl
select body from datalink.curl_get('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt');
select content_type,size from datalink.curl_save(
  '/var/www/datalink/installcheck/curl_save.txt',
  'https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt',1);
select content_type,size from datalink.curl_save(
  '/var/www/datalink/installcheck/curl_save.txt',
  'https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt',1); -- error
select * from datalink.read_text('/var/www/datalink/installcheck/curl_save.txt');

-- test transactional writes and reads

create table l1 (link datalink(2));
begin;
insert into l1 values (datalink.write_text(dlvalue('installcheck/xact1.1.txt','www'),'This is a write test file'));
select substr(link) from l1;
update l1 set link = datalink.write_text(link,'This is a write test file 1');
select substr(link) from l1;
abort;
begin;
insert into l1 values (dlvalue(datalink.write_text('/var/www/datalink/installcheck/xact1.2.txt','This is a write test file')));
select substr(link) from l1;
update l1 set link = datalink.write_text(link,'This is a write test file 2');
select substr(link) from l1;
abort;
begin;
select substr(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'));
insert into l1 values (dlreplacecontent(
  '/var/www/datalink/installcheck/xact1.3.txt',
  'https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'));
select substr(link) from l1;
update l1 set link = datalink.write_text(link,'This is a write test file 3');
select substr(link) from l1;
abort;
drop table l1;
