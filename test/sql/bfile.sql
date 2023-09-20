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

insert into bfiles (bfile) values (dlvalue('CHANGELOG.md','www'));
insert into bfiles (bfile) values (dlvalue('test1.txt','www'));
insert into bfiles (bfile) values (dlvalue('test2.txt','www'));
insert into bfiles (bfile) values (dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'));

select instr(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),'ri'),
       substr(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),1,20);

select getlength(bfile),instr(bfile,'ri'),substr(bfile,1,5),filepath(bfile),fileexists(bfile),filegetname(bfile)
  from bfiles;

select read_text(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),1,68);
select read_text(dlvalue('test3.txt#11111111-2222-3333-4444-abecedabeced','www'),35,68);

drop table bfiles;
