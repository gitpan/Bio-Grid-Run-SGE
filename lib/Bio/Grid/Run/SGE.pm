package Bio::Grid::Run::SGE;

use warnings;
use strict;

use IO::Prompt::Tiny qw/prompt/;
use Carp;

use Bio::Grid::Run::SGE::Master;
use Bio::Grid::Run::SGE::Worker;
use Bio::Grid::Run::SGE::Util qw/my_glob my_sys INFO delete_by_regex my_sys_non_fatal/;
use Bio::Grid::Run::SGE::Log::Analysis;

use File::Spec;
use File::Spec::Functions qw/catfile/;
use FindBin;
use Data::Dumper;
use Storable;
use Getopt::Long::Descriptive;
use Bio::Gonzales::Util::Cerial qw/yslurp/;
use File::Slurp qw(:std);
use Cwd qw/fastcwd/;
use Scalar::Util qw/blessed/;

use base 'Exporter';

our ( @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
our $VERSION = 0.01_01;

@EXPORT      = qw(run_job INFO my_sys my_sys_non_fatal my_glob);
%EXPORT_TAGS = ();
@EXPORT_OK   = qw();

sub run_post_task {
  my ( $config_file, $job_id, $post_task ) = @_;

  confess "config file error in worker" unless ( $config_file && -f $config_file );

  #get config
  my $c = retrieve $config_file;
  $c->{job_id} = $job_id;

  # create all summary files and restart scripts
  my $log = Bio::Grid::Run::SGE::Log::Analysis->new( c => $c, config_file => $config_file );
  $log->analyse;
  $log->write;
  $log->send_mail;

  # run post task, if desired
  $post_task->($c)
    if ( $post_task && !$c->{no_post_task} );

  return;
}

sub run_job {
  my ($a) = @_;
  confess "main task missing" unless ( $a->{task} );

  my ( $opt, $usage ) = describe_options(
    '%c %o <some_arg>',
    [ 'help|h',        'print help message and exit' ],
    [ 'clean|c',       "clean temp files" ],
    [ 'mrproper|C',    "clean temp files and config files" ],
    [ 'worker|w',      "run as worker (invoked by qsub)" ],
    [ 'post_task|p=i', "run post task with id of previous task" ],
    [ 'range|r=s',     "run predefined range" ],
    [ 'job_id=s',      "run under this job_id" ],
    [ 'id=s',          "run under this worker id" ],
    [ 'no_prompt',     "ask no confirmation stuff for running a job" ],
    [ 'node_log=i',    "rerun the nodelog stuff" ],
  );

  print( $usage->text ), exit if $opt->help;

  #this is either the original config or a serialized config object
  my $config = File::Spec->rel2abs( shift @ARGV );
  # if no config file supplied, do not change to any directory
  my $dest_dir = ( File::Spec->splitpath($config) )[1];
  chdir($dest_dir) unless ( -d $config );

  if ( $opt->worker ) {
    # WORKER

    my %worker_args = ( config_file => $config, task => $a->{task} );
    if ( defined( $opt->range ) ) {
      my @range = split /[-,]/, $opt->range;

      #one number x: from x to x
      @range = ( @range, @range )
        if ( @range == 1 );

      $worker_args{range} = \@range;
    }
    if ( defined( $opt->job_id ) ) {
      $worker_args{job_id} = $opt->job_id;
    }
    if ( defined( $opt->id ) ) {
      $worker_args{id} = $opt->id;
    }

    Bio::Grid::Run::SGE::Worker->new( \%worker_args )->run;
  } elsif ( $opt->node_log ) {
    #NODE LOG
    run_post_task( $config, $opt->node_log );
  } elsif ( $opt->post_task ) {
    #POST TASK

    run_post_task( $config, $opt->post_task, $a->{post_task} );
  } else {
    #MASTER / CLEANING

    #merge config
    my %c = ();
    if ( $config && -f $config ) {
      $config = File::Spec->rel2abs($config);
      %c      = %{ yslurp($config) };
    }
    if ( $a->{config} ) {
      %c = ( %c, %{ $a->{config} } );
    }

    $c{no_prompt} = $opt->no_prompt unless defined $c{no_prompt};
    confess "no configuration found, file: $config" unless (%c);

    #set fixed values
    $c{cmd} = ["$FindBin::Bin/$FindBin::Script"];

    #we clean
    if ( $opt->clean || $opt->mrproper ) {
      exit unless ( prompt("Clean? [yn]") eq 'y' );

      _clean_job( \%c );
      $a->{clean_task}->( \%c ) if ( $a->{clean_task} );
      if ( $opt->mrproper ) {
        exit unless ( prompt("Mr. Proper? [yn]") eq 'y' );

        _mrproper_job( \%c );
        $a->{mrproper_task}->( \%c ) if ( $a->{mrproper_task} );
      }
    } else {
      #initiate master
      if ( $a->{pre_task} ) {
        confess "pre_task is no code reference"
          if ( ref $a->{pre_task} ne 'CODE' );
      } else {
        INFO("USING DEFAULT MASTER TASK");
        $a->{pre_task} = \&_default_pre_task;
      }

      #my $current_dir = fastcwd();
      #chdir $c{working_dir} if ( exists( $c{working_dir} ) && -d $c{working_dir} );

      # put unknown configuration options into extra
      Bio::Grid::Run::SGE::Master->_unknown_attrs_to_extra( \%c );

      #get a Bio::Grid::Run::SGE::Master object
      my $m = $a->{pre_task}->( \%c );

      # if no master object is returned, just take the configuration
      # (it might have changed during the invocation of pre_task)
      $m = _default_pre_task( \%c )
        unless ( $m && blessed($m) eq 'Bio::Grid::Run::SGE::Master' );
      #chdir $current_dir;

      #confirm
      INFO( $m->to_string );
      if ( $c{no_prompt} || prompt( "run job? [yn]", 'y' ) eq 'y' ) {
        $m->run;
      }
    }
  }
  return;
}

sub _default_pre_task {
  my ($c) = @_;

  return Bio::Grid::Run::SGE::Master->new($c);
}

sub _clean_job {
  my $c = shift;
  delete_by_regex( $c->{stdout_dir}, qr/\Q$c->{job_name}\E\.o\d+\.\d+/ );
  delete_by_regex( $c->{stderr_dir}, qr/\Q$c->{job_name}\E\.e\d+\.\d+/ );
  return;
}

sub _mrproper_job {
  my $c = shift;
  delete_by_regex( $c->{result_dir}, qr/\Q$c->{job_name}\E_.*\.\d+\.result/ );
  delete_by_regex( $c->{tmp_dir},    qr/worker\.j\d+\.t[-\d]+\.tmp/ );
  delete_by_regex( $c->{tmp_dir},    qr/\Q$c->{job_name}\E\.config.dat/ );
  delete_by_regex( $c->{tmp_dir},    qr/$c->{job_name}\.idx/ );

  return;
}

1;

=head1 NAME

Bio::Grid::Run::SGE - Distribute (biological) analyses on the local SGE grid

