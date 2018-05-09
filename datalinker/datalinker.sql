--
--  datalinker
--  version 0.2 lacanoid@ljudmila.org
--
---------------------------------------------------

SET client_min_messages = warning;

---------------------------------------------------
--
---------------------------------------------------

create domain file_path text;

CREATE TABLE dl_space (
	space_id serial,
	base_path file_path NOT NULL,
	prefix file_path NULL,
	archive_path file_path NULL,
	CONSTRAINT dl_space_pkey PRIMARY KEY (space_id),
	CONSTRAINT dl_space_home_key UNIQUE (base_path),
	CONSTRAINT dl_space_url_key UNIQUE (prefix)
);

insert into dl_space (base_path)
       values ('/tmp');

table dl_space;

CREATE TABLE dl_inode (
	file_id dl_token NOT NULL DEFAULT datalink.dl_newtoken(),
	space_id int NULL,
	dev numeric NULL,
	ino numeric NULL,
	basename text NOT NULL,
	ext text NULL,
	mimetype text NULL,
	"size" numeric NOT NULL,
	state text NOT NULL DEFAULT 'new'::text,
	owner text NULL,
	"path" text NULL,
	ctime timestamptz NULL,
	mtime timestamptz NULL,
	atime timestamptz NULL,
	flags text NULL,
	blksize int4 NULL,
	rdev int4 NULL,
	blocks int8 NULL,
	uid int4 NULL,
	mode int4 NULL,
	nlink int4 NULL,
	gid int4 NULL,
	md5sum text NULL,
	CONSTRAINT dl_inode_pkey PRIMARY KEY (file_id)
) ;

alter table dl_inode add
 CONSTRAINT dl_space_ref FOREIGN KEY (space_id) REFERENCES dl_space;

CREATE OR REPLACE FUNCTION dl_space(file_path)
 RETURNS dl_space
 LANGUAGE sql
AS $function$
select * from datalink.dl_space where $1 like coalesce(prefix,base_path)||'%' 
$function$
;
 
CREATE OR REPLACE FUNCTION dl_paths(file_path, 
  out space_id int, out base_path text, out file_path text,out local_path text,out base dl_space)
 RETURNS RECORD
 LANGUAGE sql
AS $function$
  SELECT base.space_id,
         coalesce(base.archive_path,base.base_path) as base_path,
         substr($1,length(coalesce(base.prefix,base.base_path))+2) as file_path,
         coalesce(base.archive_path,base.base_path) || '/' ||
           substr($1,length(coalesce(base.prefix,base.base_path))+2) as local_path,
         base
    FROM datalink.dl_space($1) AS base
$function$;
 
CREATE OR REPLACE FUNCTION dl_inode(file_path)
 RETURNS dl_inode
 LANGUAGE plperlu
AS $function$
use Date::Format;
use Fcntl ':mode';
use Data::Dumper;

my ($file_path,$create)=@_;

my $base_info=spi_prepare(q{
  SELECT *
    FROM datalink.dl_paths($1) AS base
   }, 'datalink.file_path');

my %base = %{spi_exec_prepared($base_info,$file_path)->{rows}->[0]};
elog(NOTICE,'space:'.Dumper(\%base));
if(!$base{space_id}) {
    elog(ERROR,'File space not found. HINT: Perhaps you need to add entries to dl_space?');
    return undef;
}

my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)
    = stat($base{local_path});
my $mimetype=`file --brief --mime $base{local_path}`; chop($mimetype);

my $file_info=spi_prepare(q{
  SELECT *,
         (mtime is distinct from $2) or
         (size is distinct from $3)
         as updated
    FROM datalink.dl_inode
   WHERE path=$1
   }, 'text','timestamptz','bigint');
my %file = %{spi_exec_prepared($file_info,$file_path,time2str('%C',$mtime),$size)
           ->{rows}->[0]};
elog(NOTICE,'file:'.Dumper(\%file));

if(!$ino) {
    return undef;
}

my $state='new';
if($file{updated}eq't') { $state='updated'; }
if($file{updated}eq'f') { $state='old'; }

my %inode = (
            state=>$state,
#           file_id=>$file{file_id},
	        'basename'=>$base{local_path},
	        'path'=>$base{local_path},
            space_id=>$base{base_id},
            size=> $size,
            dev=> $dev,
            ino=> $ino,
#            mimetype=> S_ISDIR($mode)?'inode/directory':$mimetype,
            mimetype=> $mimetype,
	        'mode'=> $mode,
            nlink=> $nlink,
            uid=> $uid,
            gid=> $gid,
            rdev=> $rdev,
            atime=>time2str('%C',$atime),
            mtime=>time2str('%C',$mtime),
            ctime=>time2str('%C',$ctime),
            blksize=>$blksize,
            blocks=>$blocks  
        );

if(S_ISDIR($mode)) {
 $inode{'basename'}=~s|^.*/(.+?)/$|$1|;
} else {
 $inode{'basename'}=~s|^.*/||;
}

if($inode{'basename'}=~s|\.([^\.\/]+)$||) {
 $inode{ext}=$1;
}

return {%inode};

$function$;

 