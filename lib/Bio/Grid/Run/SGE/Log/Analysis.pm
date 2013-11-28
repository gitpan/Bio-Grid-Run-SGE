package Bio::Grid::Run::SGE::Log::Analysis;

use Mouse;

use warnings;
use strict;
use Carp;
use File::Slurp qw(:std);
use File::Spec::Functions qw/catfile/;
use Bio::Gonzales::Util::File qw/slurpc open_on_demand/;
use Mail::Sendmail;
use Bio::Grid::Run::SGE::Util qw/my_glob MSG/;
use Bio::Grid::Run::SGE::Log::Worker;

our $VERSION = 0.01_01;

has config_file    => ( is => 'rw', required   => 1 );
has c              => ( is => 'rw', required   => 1 );
has error_cmd_file => ( is => 'rw', lazy_build => 1 );
has error_log_file => ( is => 'rw', lazy_build => 1 );
has _log_report    => ( is => 'rw', default    => sub { [] } );
has _cmd_script    => ( is => 'rw', default    => sub { [] } );

sub _build_error_log_file {
  my ($self) = @_;

  my ( $tmp_dir, $job_name, $job_id ) = @{ $self->c }{qw/tmp_dir job_name job_id/};
  my $error_log_file = catfile( $tmp_dir, "$job_name.j$job_id.log" );

  return $error_log_file;
}

sub _build_error_cmd_file {
  my ($self) = @_;

  my ( $tmp_dir, $job_name, $job_id ) = @{ $self->c }{qw/tmp_dir job_name job_id/};
  my $error_cmd_file = catfile( $tmp_dir, "restart.$job_name.j$job_id.sh" );

  return $error_cmd_file;
}

sub _report_log {
  my $self = shift;
  push @{ $self->_log_report }, @_;
  return;
}

sub _report_cmd {
  my $self = shift;
  push @{ $self->_cmd_script }, @_;
  return;
}

sub analyse {
  my ($self) = @_;

  MSG("Creating node log.");

  my $c           = $self->c;
  my $config_file = $self->config_file;
  my $job_name    = $c->{job_name};
  my $job_id      = $c->{job_id};

  my $log_dir = my_glob( $c->{log_dir} );

  my $something_crashed;

  $self->_report_log( 'working_dir is ' . $c->{working_dir} );

  my %jobs_with_log;

  my $file_regex = qr/$job_name\.l$job_id\.\d+/;
  my @files      = read_dir($log_dir);
  my $STD_JOB_CMD;
  my $STD_WORKER_WD;
  my %err_hosts;
  for my $log_file (@files) {
    next unless ( $log_file =~ /$file_regex/ );
    my $log_data
      = Bio::Grid::Run::SGE::Log::Worker->new( log_file => catfile( $log_dir, $log_file ) )->log_data;

    # we cannot read the log file, skip report. these jobs will be taken care of further down
    unless ($log_data) {
      $self->_report_log("ERROR: could not parse log_file $log_file");
      next;
    }

    ( my $range = $log_data->{range} ) =~ s/[()]//g;

    # we cannot read the log file, skip report. these jobs will be taken care of further down
    unless ( $log_data->{job_cmd} && exists( $log_data->{id} ) ) {
      $self->_report_log("ERROR: could not parse log_file $log_file");
      next;
    }

    # collect jobs that have a basic log
    $jobs_with_log{ $log_data->{id} } = 1;

    ( my $job_cmd = $log_data->{job_cmd} ) =~ s/-t\s+\d+-\d+\s+//;
    $STD_JOB_CMD   = $job_cmd         unless defined $STD_JOB_CMD;
    $STD_WORKER_WD = $log_data->{cwd} unless defined $STD_WORKER_WD;

    #check for successful excecution message at the last line of the worker log
    unless ( $log_data->{'comp.end'} ) {
      #this node crashed, no end msg
      #restart the whole thing
      $something_crashed++;
      $self->_report_crashed_job(
        $log_data,
        {
          log_file => catfile( $log_dir, $log_file ),
          job_cmd  => $job_cmd,
          range    => $range,
          job_id   => $job_id,
          err_file => $log_data->{err},
          out_file => $log_data->{out},
        }
      );
      # track which nodes broke, often one specific node always breaks
      $err_hosts{ $log_data->{hostname} }++;
    } elsif ( exists( $log_data->{'comp.task.exit.error'} ) ) {
      #at least one task had an error but the worker itself survived
      $something_crashed++;
      $self->_report_error_job(
        $log_data,
        {
          log_file => catfile( $log_dir, $log_file ),
          job_cmd  => $job_cmd,
          job_id   => $job_id,
          err_file => $log_data->{err},
          out_file => $log_data->{out},
        }
      );
      # track which nodes broke, often one specific node always breaks
      $err_hosts{ $log_data->{hostname} }++;
    }
  }

  my $no_jobs_ran_at_all;
  my $total_jobs = 'n/a';
  if ( exists( $c->{range} ) ) {
    $total_jobs = $c->{range}[1] - $c->{range}[0];
  MISSING_JOBS:
    for ( my $i = $c->{range}[0]; $i <= $c->{range}[1]; $i++ ) {
      unless ( exists( $jobs_with_log{$i} ) ) {
        $something_crashed++;
        $no_jobs_ran_at_all = $self->_report_missing_job(
          {
            job_cmd => $STD_JOB_CMD,
            job_id  => $job_id,
            id      => $i,
            cwd     => $STD_WORKER_WD,
          }
        );
        last MISSING_JOBS if ($no_jobs_ran_at_all);
      }
    }
  }

  $self->_report_log("obviously, no jobs were run at all") if ($no_jobs_ran_at_all);
  if ($something_crashed) {
    # create a log entry with the hostnames and the number of times crashed.
    # often one node has all crashes and with this you can spot it easily in the log file.
    my @err_host_names = keys %err_hosts;

    @err_host_names = sort { $err_hosts{$b} <=> $err_hosts{$a} } @err_host_names;
    my @log_entries  = ("Failed hosts:");
    my $total_failed = 0;
    for my $h (@err_host_names) {
      $total_failed += $err_hosts{$h};
      push @log_entries, sprintf( "   %3d %s", $err_hosts{$h}, $h );
    }
    push @log_entries, sprintf( "TOTAL FAILED: %s of %s", $total_failed, $total_jobs );

    $self->_report_log( join( "\n", @log_entries ) );
  } else {
    $self->_report_log('all nodes finished successfully');
  }

  return;
}

sub _report_crashed_job {
  my ( $self, $log_data, $s ) = @_;

  $self->_report_cmd("#NODE: $log_data->{id}; LOG: $s->{log_file}");
  #replace job array numbers with worker id, to emulate the environment of the original array job

  $self->_report_cmd(
    "cd '$log_data->{cwd}' && $s->{job_cmd} --range $s->{range} --job_id $s->{job_id} --id $log_data->{id}");
  $self->_report_log( "Node " . $log_data->{id} . " crashed" );
  $self->_report_log("    log: $s->{log_file}");
  $self->_report_log("    err: $s->{err_file}");
  $self->_report_log("    out: $s->{out_file}");

  return;
}

sub _report_missing_job {
  my ( $self, $s ) = @_;

  unless ( $s->{job_cmd} && $s->{cwd} ) {
    return 1;
  }
  $self->_report_cmd("#NODE: $s->{id}; NO_LOG");
  #replace job array numbers with worker id, to emulate the environment of the original array job

  $self->_report_cmd("cd '$s->{cwd}' && $s->{job_cmd} --job_id $s->{job_id} --id $s->{id}");
  $self->_report_log( "Node " . $s->{id} . " crashed, NO_LOG NO_ERR NO_OUT" );

  return;
}

sub _report_error_job {
  my ( $self, $log_data, $s ) = @_;

  $self->_report_cmd("#NODE: $log_data->{id}; LOG: $s->{log_file}");

  for my $t ( @{ $log_data->{'comp.task.exit.error'} } ) {
    my ( $task_id, $files ) = split /\s/, $t, 2;

    $self->_report_cmd(
      "cd '$log_data->{cwd}' && $s->{job_cmd} --range $task_id --job_id $s->{job_id} --id $log_data->{id}");
    $self->_report_log( "Node " . $log_data->{id} . " had error(s)" );
    $self->_report_log("    log: $s->{log_file}");
    $self->_report_log("    err: $s->{err_file}");
    $self->_report_log("    out: $s->{out_file}");
  }
  return;
}

sub send_mail {
  my ($self) = @_;
  my $c = $self->c;
  return unless ( $c->{mail} );

  unshift @{ $Mail::Sendmail::mailcfg{'smtp'} }, $c->{smtp_server} if ( $c->{smtp_server} );

  MSG("Sending mail to $c->{mail}.");

  my %mail = (
    To      => $c->{mail},
    Subject => __PACKAGE__ . ' ' . $c->{job_name} . " - " . $c->{job_id},
    From    => (
      $ENV{SGE_O_LOGNAME} && $ENV{SGE_O_HOST}
      ? join( '@', $ENV{SGE_O_LOGNAME}, $ENV{SGE_O_HOST} )
      : join( '@', $ENV{USER},          $ENV{HOSTNAME} )
    ),
    Message => join( "\n", @{ $self->_log_report } ),
  );

  sendmail(%mail) or MSG($Mail::Sendmail::error);

  MSG( "Mail log says:\n", $Mail::Sendmail::log );
}

sub write {
  my ($self) = @_;

  my $cmd_f = $self->error_cmd_file;

  open my $cmd_fh, '>', $cmd_f or confess "Can't open filehandle: $!";
  print $cmd_fh join "\n", @{ $self->_cmd_script };
  $cmd_fh->close;

  chmod 0755, $cmd_f;

  my $log_f = $self->error_log_file;

  open my $log_fh, '>', $log_f or confess "Can't open filehandle: $!";
  print $log_fh join "\n", @{ $self->_log_report };
  $log_fh->close;

  #CREATE SCRIPT TO UPDATE RERUN JOBS
  $self->_write_update_script;

}

sub _write_update_script {
  my ($self) = @_;

  my $c = $self->c;

  my @post_log_cmd = ( $c->{submit_bin} );
  push @post_log_cmd, '-S', $c->{perl_bin};
  push @post_log_cmd, '-N', join( '_', 'ERRpost', $c->{job_id}, $c->{job_name} );
  push @post_log_cmd, '-e', $c->{stderr_dir};
  push @post_log_cmd, '-o', $c->{stdout_dir};
  push @post_log_cmd, @{ $c->{cmd} }, '--node_log', $c->{job_id}, $self->config_file;

  my $update_log_file = catfile( $c->{tmp_dir}, "update.$c->{job_name}.j$c->{job_id}.sh" );

  open my $update_log_fh, '>', $update_log_file or confess "Can't open filehandle: $!";
  print $update_log_fh join( " ", "cd", "'" . $c->{working_dir} . "'", '&&', @post_log_cmd ), "\n";
  $update_log_fh->close;

  chmod 0755, $update_log_file;

  return;
}

__PACKAGE__->meta->make_immutable();
