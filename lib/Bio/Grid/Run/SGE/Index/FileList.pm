package Bio::Grid::Run::SGE::Index::FileList;

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

  confess 'No write permission, set write_flag to write' unless ( $self->writeable );

  if ( $self->_is_indexed) {
    print STDERR "SKIPPING INDEXING STEP, THE INDEX IS UP TO DATE\n";
    return $self;
  }

  print STDERR "INDEXING ....\n";

  my $abs_input_files = $self->_glob_input_files($input_files);

  #FIXME chunks should be possible
  $self->idx($abs_input_files);

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

__END__

=head1 NAME

Bio::Grid::Run::SGE::Index::FileList - Creates an index from a list of files

=head1 SYNOPSIS

  my $idx = Bio::Grid::Run::SGE::Index::FileList->new(
    'writeable' => 1,
    'idx_file'  => '/tmp/example_file_index'
  );

  my @files = (...);
  $idx->create( \@files );

  my $number_of_elements = $idx->num_elem, 3 );    # is equal to the number of files in @files

  for ( my $i = 0; $i < $number_of_elements; $i++ ) {
      my $data = $idx->get_elem($i);
  }

=head1 DESCRIPTION

=head1 OPTIONS

=head1 SUBROUTINES
=head1 METHODS

=head1 SEE ALSO

=head1 AUTHOR

jw bargsten, C<< <jwb at cpan dot org> >>

=cut
