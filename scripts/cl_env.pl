#!/usr/bin/env perl

use warnings;
use strict;

use Carp;
use Data::Dumper;

use Bio::Grid::Run::SGE;
use Bio::Gonzales::Util::Cerial;

use File::Spec;

run_job(
  {
    task => sub {
      my ( $c, $result_prefix, $item ) = @_;

      INFO "Running $item -> $result_prefix";
      jspew( $result_prefix . ".json", \%ENV );
      sleep 3;

      return 1;
    },
    post_task => sub {
      my $c = shift;
      open my $fh, '>', File::Spec->catfile( $c->{result_dir}, 'finished' )
        or die "Can't open filehandle: $!";
      say $fh $c->{job_id};
      $fh->close;
      }
  }
);

1;
