use warnings;
use Data::Dumper;
use Test::More;
use Gonzales::Util::Cerial qw/yspew yslurp/;
use Storable;
use File::Temp qw/tempdir/;
use File::Spec::Functions qw/catfile rel2abs/;
use Cwd qw/fastcwd/;
use Gonzales::Util::Cerial;


BEGIN { use_ok('Bio::Grid::Run::SGE::Master'); }

my $td = tempdir( CLEANUP => 1 );

$ENV{SGE_TASK_ID} = 1;
$ENV{JOB_ID}      = -1;

undef $Bio::Grid::Run::SGE::Master::RC_FILE;

{
  my $c = { test => 3, unknown_attr1 => 1, unknown_attr2 => 2, mode => 'Dummy' };
  Bio::Grid::Run::SGE::Master->_unknown_attrs_to_extra($c);
  my $e = $c->{extra};
  is_deeply(
    $c,
    {
      'test' => 3,
      'mode' => 'Dummy',
      extra => {
        unknown_attr1 => 1,
        unknown_attr2 => 2,
      },
    },
    "configuration without unknown attributes"
  );
  is_deeply(
    $e,
    {
      'unknown_attr1' => 1,
      'unknown_attr2' => 2
    },
    "extra with unknown attributes"
  );
}

{

  my $m = Bio::Grid::Run::SGE::Master->meta;

  diag jfreeze( [ map { $_->name } $m->get_all_attributes ]);
}


my $m = Bio::Grid::Run::SGE::Master->new(
  working_dir      => $td,
  submit_bin       => 't/Bio-Grid-Run-SGE-Master.qsub.pl',
  cmd              => ['t/Bio-Grid-Run-SGE-Master.script.pl'],
  perl_bin         => 'perl',
  input            => [ { format => 'General', sep => '^>', files => ['t/data/test.fa'], } ],
  use_stdin        => 1,
  result_on_stdout => 1,
  mode             => 'Dummy',
);

my ( $cmd, $c ) = $m->cache_config("$td/master_config");

my $run_output = retrieve("$td/master_config");

my $run_output_ref = yslurp('t/data/Bio-Grid-Run-SGE-Master_run.yml');
#diag Dumper $run_output;

#get the naming of the temp dir right
@{$run_output_ref}{qw/working_dir stderr_dir tmp_dir result_dir log_dir/}
  = map { $_ ? catfile( $td, $_ ) : $td } ( '', qw(tmp/err tmp result tmp/log) );
$run_output_ref->{input}[0]{idx_file} = catfile( $td, 'idx/cluster_job.0.idx' );
$run_output_ref->{job_cmd}             =~ s!/tmp/lXGH5pgD5r!$td!g;
$run_output_ref->{_worker_config_file} =~ s!/tmp/lXGH5pgD5r!$td!g;
my $curdir = fastcwd;
$run_output_ref->{job_cmd}  =~ s!PERL!perl!g;
$run_output_ref->{perl_bin} =~ s!PERL!perl!g;
$run_output_ref->{stdout_dir} = catfile( $td, 'tmp', 'out' );
$run_output_ref->{idx_dir} = catfile( $td, 'idx' );
$run_output_ref->{script_dir} = rel2abs('t');

#yspew 't/data/Bio-Grid-Run-SGE-Master_run1.yml', $run_output;
is_deeply( $run_output, $run_output_ref );

$ENV{BIO_GRID_RUN_SGE_TESTDIR} = $td;

#FIXME check output of the run function call
$run_output = $m->run;
#cmp_deeply( $run_output, $run_output_reference, $d );
ok( -f catfile( $td, "tmp", "log", "main.cluster_job.j-1.cmd" ) );

my $qsub_argv = yslurp( catfile( $td, 'master.qsub.cmd' ) );

is_deeply(
  $qsub_argv,
  [
    '-t', '1-45',
    '-S', 'perl',
    '-N', 'cluster_job',
    '-e', catfile( $td, 'tmp/err' ),
    '-o', catfile( $td, 'tmp/out' ),
    catfile( $td, 'tmp/env.cluster_job.pl' ), 't/Bio-Grid-Run-SGE-Master.script.pl',
    '--worker', catfile( $td, 'tmp/cluster_job.config.dat' )
  ]
);

done_testing();
