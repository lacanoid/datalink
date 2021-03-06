\pset null _null_

SET client_min_messages = notice;
SET search_path = public,datalink;

alter table sample_urls alter url type datalink.dl_url;

insert into sample_urls (url)
values 
  ('file://user@fs1.arch.net/file1.jpg'),
  ('file://user@file-server/a/b/c/../../fileX.jpg'),
  ('file://user@fs2.arch.net/file1.jpg#bb519e69-6bf1-4214-9b7a-4280702c6321'),
  ('file://user:pass@host/fileA.txt'),
  ('ftp://user:pass@host/fileB.txt'),
  ('sftp://user:pass@host/fileC.txt#80653c50-908b-4f74-a7ca-398a6035a2d1'),
  ('mailto:lacanoid@ljudmila.org?subject=feedback'),
  ('https://video.kulturnik.si/?qwhat=galerije&q=piran')
;

insert into sample_urls (url) values ('data:image/gif;base64,R0lGODlhyAAiALM...DfD0QAADs=');

select url,
       uri_get(url,'scheme') as scheme,
       uri_get(url,'userinfo') as userinfo,
       uri_get(url,'host') as host,
       uri_get(url,'path') as path,
       uri_get(url,'query') as query,
       uri_get(url,'fragment') as fragment
  from sample_urls
;

select url,dlpreviouscopy(url::text,0) from sample_urls;

select 'foo/bar'::datalink.file_path;
select '/foo/bar'::datalink.file_path;
select '/foo/bar/..'::datalink.file_path;
select '/foo/../bar'::datalink.file_path;
