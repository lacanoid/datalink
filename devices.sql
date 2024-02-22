---------------------------------------------------
-- disk free
---------------------------------------------------
CREATE OR REPLACE FUNCTION devices(
  OUT dev integer, OUT filesystem text, OUT fstype text, OUT mountpoint text, 
  OUT size numeric, OUT used numeric, OUT avail numeric, OUT "%use" double precision, OUT options text[])
 RETURNS SETOF record
 LANGUAGE plperlu
 COST 1000 ROWS 10
AS $function$
# Get UNIX file system information
# this uses UNIX df(1) and mount(1) commands

my %d=();

# reported by df(1)
my $df=`df -B1 -a -P`;my @df=split(/[\n\r]+/,$df); shift @df;
for my $l (@df) { 
	my @a=split(/\s+/,$l); my $i=$a[0];
	$d{$i}={
		'filesystem'=>$i,'size'=>$a[1],'used'=>$a[2],
		'avail'=>$a[3],'%use'=>$a[4],'mountpoint'=>$a[5]
	};
	if( $d{$i}{'size'}eq'-')  { $d{$i}{'size'}=undef; } 
	if( $d{$i}{'used'}eq'-')  { $d{$i}{'used'}=undef; } 
	if( $d{$i}{'avail'}eq'-') { $d{$i}{'avail'}=undef; } 
	if( $d{$i}{'%use'}eq'-')  { $d{$i}{'%use'}=undef; } 
	else { $d{$i}{'%use'}=~s/%//; }
	my @stat=stat($d{$i}{'mountpoint'});
	$d{$i}{'dev'}=$stat[0];
}

# reported by mount(1)
my $mt=`mount`; my @mt=split(/[\n\r]+/,$mt);
for my $l (@mt) {
	my @a=split(/\s+/,$l);
	$d{$a[0]}{'fstype'}=$a[4];
	$d{$a[0]}{'options'}=$a[5];
	$d{$a[0]}{'options'}=~y/\(\)/\{\}/;
}

for my $i (keys(%d)) { return_next($d{$i}); }

return undef;
$function$;

COMMENT ON FUNCTION devices() IS 'Get disk device information';
REVOKE ALL ON FUNCTION devices() FROM PUBLIC;

CREATE OR REPLACE VIEW devices AS
 SELECT dev,
        filesystem,
        fstype,
        mountpoint,
        size,
        used,
        avail,
        "%use",
        options
   FROM datalink.devices()
  WHERE fstype IS NOT NULL and dev is not null;
COMMENT ON VIEW devices IS 'Get disk device information';
GRANT SELECT ON devices TO PUBLIC;

