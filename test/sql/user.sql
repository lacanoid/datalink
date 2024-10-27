\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

-- test permissions on web functions
select datalink.has_web_privilege('http://www.ljudmila.org'); -- yes, root

begin;

create role datalink_test_user;
grant all on schema public to datalink_test_user;
set role datalink_test_user;

create table user_links (
  id serial,
  link datalink,
  link2 datalink
);

select datalink.has_web_privilege('http://www.ljudmila.org'); -- no

reset role;

insert into datalink.dl_access_web values ('http://www.ljudmila.org','SELECT','datalink_test_user'::regrole);
set role datalink_test_user;
select datalink.has_web_privilege('http://www.ljudmila.org'); -- yes
reset role;


update datalink.columns
   set link_control='FILE', integrity='ALL',
       read_access='DB', write_access='TOKEN',
       recovery='YES', on_unlink='RESTORE'
 where table_name='user_links' and column_name='link';

update datalink.columns
   set link_control='FILE', integrity='ALL'
 where table_name='user_links' and column_name='link2';

set role datalink_test_user;

insert into user_links (link)
values (dlvalue('/var/www/datalink/test1.txt','FS','Sample file datalink 1'));

update user_links
   set link = dlnewcopy(link);

select * 
  from datalink.linked_files;

update user_links set link = null;

truncate user_links;

savepoint p1;
-- test permissions on file functions
select * from datalink.read_text('/etc/passwd',1,4); -- should fail
rollback to p1;

select * from datalink.read_text('/var/www/datalink/test1.txt',1,5);

reset role;
drop table user_links;
revoke all on schema public from datalink_test_user;
drop role datalink_test_user;

abort;



