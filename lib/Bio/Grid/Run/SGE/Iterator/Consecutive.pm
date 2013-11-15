package Bio::Grid::Run::SGE::Iterator::Consecutive;

use Mouse;

use warnings;
use strict;

use constant {
    FROM_IDX            => 0,
    TO_IDX              => 1,
    EXTRA_IDX           => 2,
    BEYOND_LAST_ELEMENT => -2,
};

our $VERSION = 0.01_01;

has cur_comb_idx => ( is => 'rw', lazy_build => 1 );

with 'Bio::Grid::Run::SGE::Role::Iterable';

sub next_comb {
    my ($self) = @_;

    unless ( $self->_iterating ) {
        confess "you need to start the iterator with a predefined range";
    }

    return if ( $self->cur_comb_idx == BEYOND_LAST_ELEMENT );

    my $cidx = $self->cur_comb_idx + 1;

    $self->cur_comb_idx($cidx);
    if ( $cidx > $self->num_comb ) {
        confess "You specified a range that is bigger than the number of combinations";
    }

    if ( $cidx > $self->_range->[TO_IDX] ) {
        my $comb;
        if ( defined( $self->_range->[EXTRA_IDX] ) ) {
            $self->cur_comb_idx( $self->_range->[EXTRA_IDX] );
            $comb = $self->cur_comb;
        }
        $self->cur_comb_idx(BEYOND_LAST_ELEMENT);
        return $comb;
    }

    return $self->cur_comb;
}

sub start {
    my ( $self, $idx_range ) = @_;

    if ( $self->_iterating ) {
        map { $_->close } @{ $self->indices };
    }
    $self->_range($idx_range);

    $self->_iterating(1);
    $self->cur_comb_idx( $idx_range->[FROM_IDX] - 1 );

    return;
}

sub cur_comb {
    my ($self) = @_;

    #we did not start yet.
    return if ( $self->cur_comb_idx == BEYOND_LAST_ELEMENT );

    return [ $self->indices->[0]->get_elem( $self->cur_comb_idx ) ];
}

sub num_comb {
    my ($self) = @_;

    return $self->indices->[0]->num_elem;
}

sub peek_comb_idx {
    my ($self) = @_;

    return
        unless ( $self->_iterating );

    return if ( $self->cur_comb_idx == BEYOND_LAST_ELEMENT );

    my $cidx = $self->cur_comb_idx + 1;

    if ( $cidx > $self->num_comb ) {
        confess "You specified a range that is bigger than the number of combinations";
    }

    if ( $cidx > $self->_range->[TO_IDX] ) {
        return $self->_range->[EXTRA_IDX]
            if ( defined( $self->_range->[EXTRA_IDX] ) );
        return;
    }

    return $cidx;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

  Bio::Grid::Run::SGE::Iterator::Consecutive - iterate consecutively through an index

=head1 SYNOPSIS

  my $index = Bio::Grid::Run::SGE::Index->new( format => 'Dummy', idx_file => undef )->create;

  my $it = Bio::Grid::Run::SGE::Iterator::Consecutive->new( indices => [$index] );

  # iterate from combinations 3 to 8
  $it->start( [ 3, 8 ] );

  my @result;
  while ( my $combination = $it->next_comb ) {
    push @result, $comb->[0];
  }

=head1 DESCRIPTION

This is the simplest iterator, it runs through a range of elements in an index.

=head1 ADDITIONAL METHODS

This index inherits methods from L<Bio::Grid::Run::SGE::Role::Iterable>. See
documentation at L<Bio::Grid::Run::SGE::Role::Iterable> for more information.

Only additional methods are documented here.

=head1 SEE ALSO

L<Bio::Grid::Run::SGE::Role::Iterable>, L<Bio::Grid::Run::SGE::Iterator>

=head1 AUTHOR

jw bargsten, C<< <jwb at cpan dot org> >>

=cut
