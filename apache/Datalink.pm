package Datalink;

use strict;
use warnings;
  
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK FORBIDDEN DECLINED);
use APR::Finfo ();
use APR::Const -compile => qw(FINFO_NORM);
use JSON;
use DBI;

sub handler {
  my $r = shift;
  my $filename = $r->filename();

  my $dbh = DBI->connect("dbi:Pg:dbname=postgres",undef,undef,{RaiseError=>0});
  my $sth = $dbh->prepare('select datalink.dl_authorize($1,true)');
  $sth->execute($filename);

  my $ref  = $sth->fetchrow_arrayref;
  $filename = $ref->[0];
  if(defined($filename) && length($filename)>0) {
    # $r->content_type('text/plain');
    # $r->print("File is: $filename\n");
    # return Apache2::Const::OK; # or another status constant

    $r->filename($filename);
    $r->finfo(APR::Finfo::stat($filename, APR::Const::FINFO_NORM, $r->pool));
    return Apache2::Const::DECLINED;
  } else {
    return Apache2::Const::FORBIDDEN;    
  }
  return Apache2::Const::DECLINED;
}
1;
  