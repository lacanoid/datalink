BEGIN;

SET search_path TO datalink;

/*
drop aggregate write_lines(file_path,text);
drop function if exists write_lines_sfunc;
drop function if exists write_lines_ffunc;
*/

-- 1. State transition function with eval guard and orphan cleanup
CREATE OR REPLACE FUNCTION write_lines_sfunc(state text, filepath file_path, val text)
RETURNS text AS $function$
    use strict;
    use Fcntl qw(O_WRONLY O_CREAT O_EXCL);

    my ($state, $filepath, $val) = @_;
    my $op = 't';
    return $state unless defined $filepath;
    my $pid = $$;

    # Initialize on the first row
    if (!defined $state) {
        # Sweep any orphaned handles from previously aborted queries in this session
        # (Safe because PARALLEL UNSAFE ensures only one aggregate runs at a time per backend)
        for my $old_key (grep { /^pgdlwlfh_${pid}_/ } keys %_SHARED) {
            my $orphan = delete $_SHARED{$old_key};
            close($orphan->{fh}) if $orphan->{fh};
            unlink($orphan->{path}) if defined $orphan->{path} && -e $orphan->{path};
        }

        $state = "pgdlwlfh_${pid}_".int(rand(1_000_000_000))."_".time();

        my $q = q{select datalink.has_file_privilege($1,$2,true) as ok, user};
        my $p = spi_prepare($q,'datalink.file_path','text');
        my $fs = spi_exec_prepared($p,$filepath,'create')->{rows}->[0];
        unless($fs->{ok} eq 't') { 
                die qq{DATALINK EXCEPTION - CREATE permission denied on directory}.
                    qq{\nFILE:  $filepath\nROLE:  }.quote_ident($fs->{user})."\n"; 
        }

        if(-e $filepath) { die "DATALINK EXCEPTION - file exists\nFILE:  $filepath\n"; }

        $p = spi_prepare(q{select datalink.dl_file_new($1,$2)},
	                 'datalink.file_path','"char"');
        unless(spi_exec_prepared($p,$filepath,$op))
          { die "DATALINK EXCEPTION - dl_file_new() failed"; }

        my $fh;
	sysopen($fh,$filepath,O_WRONLY|O_CREAT|O_EXCL,0666)
            or elog(ERROR, "Cannot open file '$filepath': $!");

        $_SHARED{$state} = { fh => $fh, path => $filepath };
    }

    # Write row inside an eval block to guarantee cleanup on I/O failure
    if (defined $val) {
        eval {
            my $entry = $_SHARED{$state}
                or die "Missing file handle state '$state'\n";
            my $fh = $entry->{fh};
	    chomp($val);
	    utf8::encode($val);
            print $fh "$val\n"
                or die "Failed writing to '$entry->{path}': $!\n";
            1;
        } or do {
            my $err = $@ || "Unknown write error";
            if (my $entry = delete $_SHARED{$state}) {
                close($entry->{fh}) if $entry->{fh};
                unlink($entry->{path}) if defined $entry->{path} && -e $entry->{path};
            }
            elog(ERROR, $err);
        };
    }

    return $state;
$function$ LANGUAGE plperlu VOLATILE;

-- 2. Final function: closes the file cleanly
CREATE OR REPLACE FUNCTION write_lines_ffunc(state text)
RETURNS text AS $$
    my ($state) = @_;
    return undef unless defined $state && exists $_SHARED{$state};

    my $entry = delete $_SHARED{$state};
    my $fh    = $entry->{fh};
    my $path  = $entry->{path};

    if (!close($fh)) {
        unlink($path) if defined $path && -e $path;
        elog(ERROR, "Error closing file '$path': $!");
    }

    return $path;
$$ LANGUAGE plperlu VOLATILE;

CREATE OR REPLACE AGGREGATE write_lines(file_path, text) (
    SFUNC = write_lines_sfunc,
    STYPE = text,
    FINALFUNC = write_lines_ffunc
);

end;
