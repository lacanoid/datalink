\pset null _null_

select *
  from datalink.dl_space('/etc');
  
select *
  from datalink.dl_space('/tmp/');
  
select *
  from datalink.dl_space('/tmp/zzzz');

-----------------------------------------

select *
  from datalink.dl_paths('/etc');
  
select *
  from datalink.dl_paths('/tmp/');
  
select *
  from datalink.dl_paths('/tmp/zzzz');

-----------------------------------------

select *
  from datalink.dl_inode('/etc');

select *
  from datalink.dl_inode('/tmp/');
  
select *
  from datalink.dl_inode('/tmp/zzzz');
  
  