use warnings;
use Test::More;
use Capture::Tiny qw/capture/;
use Data::Dumper;
use File::Temp qw/tempdir/;
use Bio::Grid::Run::SGE::Util qw/poll_interval/;
use Bio::Gonzales::Util::Cerial;

use File::Spec;
use File::Slurp qw/read_dir/;
use List::Util;
use Cwd qw/fastcwd/;
use File::Which;
use File::Path qw/remove_tree/;

BEGIN {
  my $qsub = which('qsub');

  unless ($qsub) {
    plan skip_all => 'This test requires qsub';
  }

  use_ok('Bio::Grid::Run::SGE');
}

my $cl_env = File::Spec->rel2abs("scripts/cl_env.pl");

my $tmp_dir = File::Spec->rel2abs('tmp_test');
mkdir $tmp_dir unless ( -d $tmp_dir );

my $job_dir = tempdir( CLEANUP => 1, DIR => $tmp_dir );

my $job_name   = 'test_env';
my $result_dir = 'r';

my @elements = ( 'a', 'b', 'c', 'd', 'e', 'f' );
# create basic config
my $basic_config = {
  input      => [ { format => 'List', elements => \@elements } ],
  job_name   => $job_name,
  mode       => 'Consecutive',
  no_prompt  => 1,
  result_dir => $result_dir,
};

yspew( "$job_dir/conf.yml", $basic_config );

SKIP: {
  my ( $stdout, $stderr, $exit ) = capture {
    system("$^X $cl_env $job_dir/conf.yml");
  };

  unless ( $exit == 0 ) {
    if ( $stderr =~ /\Q[SUBMIT_ERROR]\E/ ) {
      skip "could not submit jobs to the live system", 2;
    } else {
      fail "submission failed: $?\n$stderr$stdout";
    }
  }

  diag "THIS TEST MIGHT TAKE UP TO 30 MINUTES";
  my $max_time = 30 * 60;
  my $wait_time = poll_interval( 1, $max_time );
  my $finished_successfully;
  while ( $wait_time < $max_time ) {

    diag "  next poll in $wait_time seconds";
    sleep $wait_time;

    if ( -f "$job_dir/$result_dir/finished" ) {
      open my $fh, '<', "$job_dir/$result_dir/finished" or die "Can't open filehandle: $!";
      $finished_successfully = <$fh>;
      $fh->close;
      chomp $finished_successfully;
      last;
    }
    $wait_time = poll_interval( $wait_time, $max_time );
  }
  ok($finished_successfully);

  my @files = grep {m/$job_name.*$finished_successfully.*\.env\.json$/}
    read_dir( "$job_dir/$result_dir", prefix => 1 );

  my $env = jslurp( $files[-2] );

  is( $env->{JOB_NAME}, $job_name );

  jspew( "$tmp_dir/env.json", $env );

  my %found_elements;
  my @item_files = grep {m/$job_name.*$finished_successfully.*\.item\.json$/}
    read_dir( "$job_dir/$result_dir", prefix => 1 );
  for my $f (@item_files) {
    my $items = jslurp($f);
    for my $item (@$items) {
      $found_elements{$item}++;
    }
  }
  is_deeply( [ sort keys %found_elements ], [ sort @elements ] );
}

remove_tree($tmp_dir);
done_testing();
