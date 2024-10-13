\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

select getlength(dlvalue('/var/www/datalink/test2.txt'));

select substr(dlvalue('/var/www/datalink/test2.txt')),
       substr(dlvalue('/var/www/datalink/test2.txt'),12),
       substr(dlvalue('/var/www/datalink/test2.txt'),12,8)
       ;

select instr(dlvalue('/var/www/datalink/test2.txt'),'Feb');

create domain bfile datalink(2);
create table bfiles ( bfile bfile );

insert into bfiles (bfile) values (dlvalue('LICENSE.md','www'));
insert into bfiles (bfile) values (dlvalue('test1.txt','www'));
insert into bfiles (bfile) values (dlvalue('test2.txt','www'));
insert into bfiles (bfile) values (dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'));

select instr(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),'ri'),
       substr(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),1,21);

select getlength(bfile),instr(bfile,'link'),substr(bfile,1,5),filepath(bfile),fileexists(bfile),filegetname(bfile)
  from bfiles;

select read_text(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),1,68);
select read_text(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),48,48);

drop table bfiles;

select read_text('/var/www/datalink/utf8.txt');
select read_text('/var/www/datalink/utf8.txt',11);
select read_text('/var/www/datalink/utf8.txt',11,10);
select read_text(dlvalue('/var/www/datalink/utf8.txt'));
select read_text(dlvalue('/var/www/datalink/utf8.txt'),11);
select read_text(dlvalue('/var/www/datalink/utf8.txt'),11,10);
select read_text(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'));
select read_text(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),11);
select read_text(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),11,10);

select * from read_lines('/var/www/datalink/utf8.txt');

select read('/var/www/datalink/utf8.txt');
select read('/var/www/datalink/utf8.txt',4);
select read('/var/www/datalink/utf8.txt',4,10);
select read(dlvalue('/var/www/datalink/utf8.txt'));
select read(dlvalue('/var/www/datalink/utf8.txt'),4);
select read(dlvalue('/var/www/datalink/utf8.txt'),4,10);
select read(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'));
select read(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),4);
select read(dlvalue('https://raw.githubusercontent.com/lacanoid/datalink/refs/heads/master/docs/utf8.txt'),4,10);

insert into my_table2 values (dlvalue('/var/www/datalink/utf8.txt'));
select datalink.has_updated(link) from my_table2;
\! touch /var/www/datalink/utf8.txt
select datalink.has_updated(link) from my_table2;
select datalink.has_updated(link) from my_table2;
select datalink.has_updated(dlvalue('/var/www/datalink/utf8.txt'));
update my_table2 set link=dlnewcopy(link);
select datalink.has_updated(link) from my_table2;
select datalink.has_updated(dlvalue('/var/www/datalink/utf8.txt'));
truncate my_table2;
select datalink.has_updated(dlvalue('/var/www/datalink/utf8.txt'));

select datalink.has_updated('/etc/issue');

---
-- test link construction types

create table files ( link datalink(2) );
insert into files values (dlvalue('/var/www/datalink/test1.txt'));
update files set link = dlnewcopy(link);
insert into files values (dlvalue('/var/www/datalink/test2.txt'));
insert into files values (dlreplacecontent('/var/www/datalink/robots.txt','http://www.github.com/robots.txt'));
insert into files values (datalink.write_text(dlvalue('test5.txt','www'),'This is a test file 5'));

select cons,path from datalink.dl_linked_files order by path;

drop table files;
