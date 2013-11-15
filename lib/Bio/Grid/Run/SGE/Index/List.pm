package Bio::Grid::Run::SGE::Index::List;

use Mouse;

use warnings;
use strict;
use Carp;
use Storable qw/retrieve/;
use List::MoreUtils qw/uniq/;
use File::Slurp;

with 'Bio::Grid::Run::SGE::Role::Indexable';

our $VERSION = 0.01_01;

sub BUILD {
  my ($self) = @_;

  confess "index file not set"
    unless ( $self->idx_file );
  if ( -f $self->idx_file ) {
    $self->_load_index;
  }

  return $self;
}

sub create {
  my ( $self, $input_files ) = @_;

  if ( $self->_is_indexed ) {

    print STDERR "SKIPPING INDEXING STEP, THE INDEX IS UP TO DATE\n";
    return $self;
  }
  confess 'No write permission, set write_flag to write' unless ( $self->writeable );

  my $chunk_size = $self->chunk_size;

  #FIXME chunks should be possible
  $self->idx( [@$input_files] );

  $self->_store;
  return $self;
}

sub _is_indexed {
  my ($self) = @_;

  return if ( $self->_reindexing_necessary );
  return unless ( @{ $self->idx } > 0 && -f $self->idx_file );

  return 1;
}

sub num_elem {
  my ($self) = @_;

  return scalar @{ $self->idx };
}

sub get_elem {
  my ( $self, $elem_idx ) = @_;
  my $idx = $self->idx;

  return $idx->[$elem_idx];
}

sub type {
  return 'direct';
}

sub close { }

__PACKAGE__->meta->make_immutable;
1;
