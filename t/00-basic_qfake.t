use warnings;
use Test::More;
use Data::Dumper;
use File::Temp qw/tempdir/;
use Bio::Grid::Run::SGE::Util qw/poll_interval/;
use Gonzales::Util::Cerial;
use File::Spec;
use File::Slurp qw/read_dir/;
use List::Util;
use Cwd qw/fastcwd/;

BEGIN { use_ok('Bio::Grid::Run::SGE'); }

my $cl_env   = File::Spec->rel2abs("scripts/cl_env.pl");

my $tmp_dir = 'tmp_test';
mkdir $tmp_dir unless ( -d $tmp_dir );

my $job_dir = tempdir( CLEANUP => 1, DIR => $tmp_dir );

my $job_name   = 'test_env';
my $result_dir = 'r';

# create basic config
my $basic_config = {
  input      => [ { format => 'List', elements => [ 'a', 'b', 'c', 'd', 'e', 'f' ] } ],
  job_name   => $job_name,
  mode       => 'Consecutive',
  no_prompt  => 1,
  result_dir => $result_dir,
  submit_bin => File::Spec->rel2abs('bin/qfake.pl'),
};

yspew( "$job_dir/conf.yml", $basic_config );

system("$cl_env $job_dir/conf.yml");

diag "THIS TEST MIGHT TAKE UP TO 30 MINUTES";
my $max_time = 30 * 60;
my $wait_time = poll_interval( 1, $max_time );
my $finished_successfully;
while ( $wait_time < $max_time) {

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

my @files = grep {m/$job_name.*$finished_successfully.*\.json$/} read_dir( "$job_dir/$result_dir", prefix => 1 );

my $env = jslurp( $files[-2] );

is($env->{JOB_NAME}, $job_name);

done_testing();
