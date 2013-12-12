package Bio::Grid::Run::SGE::Config;

use Mouse;

use warnings;
use strict;
use Carp;

use 5.010;

use Config::Auto;
use Bio::Gonzales::Util::Cerial;
use Bio::Grid::Run::SGE::Master;
use FindBin;

our $VERSION = 0.01_01;

has 'job_config_file' => ( is => 'rw' );
has 'cluster_script_setup' => ( is => 'rw', default => sub { {} } );
has 'config' => ( is => 'rw', lazy_build => 1 );
has 'opt' => (
  is      => 'rw',
  default => sub {
    {

    };
  }
);
has 'rc_file' => (
  is      => 'rw',
  default => sub {
    "$ENV{HOME}/.bio-grid-run-sge.conf.yml";
  }
);

has _old_rc_files => (
  is      => 'rw',
  default => sub {
    [ "$ENV{HOME}/.comp_bio_cluster.config", "$ENV{HOME}/.bio-grid-run-sge.conf", ];
  }
);


sub hide_notify_settings {
  my $self = shift;

  my $c = $self->config;
  delete $c->{notify} if(exists($c->{notify}));
  return $self;
}
sub _read_old_rc_files {
  my $self = shift;

  my %c;
  for my $rcf ( @{ $self->_old_rc_files } ) {

    my $c_tmp = eval { Config::Auto::parse($rcf) } if ( $rcf && -f $rcf );
    if ( $c_tmp && !$@ ) {
      print STDERR "Found DEPRECATED config file: " . $rcf . "\n";
      print STDERR "Please switch to the new format (YAML) and name (~/.bio-grid-run-sge.conf.yml)\n";
      %c = ( %c, %$c_tmp );
    }

  }
  return \%c;
}

sub _read_rc_file {
  my $self = shift;

  my $rcf = $self->rc_file;
  return yslurp($rcf) if ( $rcf && -f $rcf );

  return {};
}

sub _build_config {
  my $self        = shift;
  my $config_file = $self->job_config_file;
  my $a           = $self->cluster_script_setup;
  my $opt         = $self->opt;

  #merge config
  # global options always get overwritten by local config

  my %c = ( %{ $self->_read_old_rc_files }, %{ $self->_read_rc_file } );

  # from the config in the cluster script
  if ( $a->{config} ) {
    %c = ( %c, %{ $a->{config} } );
  }

  # from config file
  if ( $config_file && -f $config_file ) {
    %c = ( %c, %{ yslurp($config_file) } );
  }

  $c{no_prompt} = $opt->{no_prompt} unless defined $c{no_prompt};
  confess "no configuration found, file: $config_file" unless (%c);

  _adjust_deprecated( \%c );
  _unknown_attrs_to_extra( \%c );
  return \%c;
}

sub _adjust_deprecated {
  my $c = shift;
  if ( exists( $c->{method} ) && !exists( $c->{mode} ) ) {
    warn "The configuration option 'method' is DEPRECATED, use 'mode' instead.";
    $c->{mode}   = $c->{method};
    $c->{method} = "DEPRECATED: The configuration option 'method' is DEPRECATED, use 'mode' instead.";
  }
  return;
}

# put unknown configuration options into extra
sub _unknown_attrs_to_extra {
  my $c = pop;
  my $m = Bio::Grid::Run::SGE::Master->meta;

  $c->{extra} //= {};
  my %attrs = map { $_->name => 1 } $m->get_all_attributes;
  for my $k ( keys %$c ) {
    unless ( exists( $attrs{$k} ) ) {
      $c->{extra}{$k} = delete $c->{$k};
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable();
