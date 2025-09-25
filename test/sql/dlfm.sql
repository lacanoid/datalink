-- reload
drop table IF EXISTS l1;
drop extension if exists datalink;
create extension if not exists datalink;
create table l1 (link datalink(272));

/*
-- test on unlink delete in transaction
insert into datalink.access values ('/var/www/datalink/','DELETE',current_role::regrole);

begin;
insert into l1 values (dlvalue('/var/www/datalink/test2.txt'));
table datalink.linked_files;
delete from l1;
table datalink.linked_files;
end;

call datalink.commit();
table datalink.linked_files;
*/

-- test updates and file reads

truncate l1;

begin;
insert into l1 values(dlvalue(datalink.write_text('/var/www/datalink/installcheck/writetest.txt','This is a write test file')));
select link,dlurlpath(link),datalink.dl_authorize(dlurlpath(link)) from l1;
-- call datalink.commit();
update l1 set link=datalink.write_text(link,'This is another write test file');
select link,dlurlpath(link),datalink.dl_authorize(dlurlpath(link)) from l1;
end;

truncate l1;
