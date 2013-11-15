package Bio::Grid::Run::SGE::Iterator::AllvsAllNoRep;

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

sub num_comb {
    my ($self) = @_;

    my $i = $self->indices->[0]->num_elem;

    return ( ($i) * ( $i - 1 ) ) / 2;
}

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

sub _position {
    my ( $self, $comb_idx ) = @_;

    my $idx_num_elem = $self->indices->[0]->num_elem;

    #$idx_num_elem = number of rows = number of columns
    my $num_comb = $self->num_comb;

    #the counting starts from 0 or 1, but we need the elements left (inverted)
    #since I assume the triangular matrix to be the function f(x) = x
    my $k = $num_comb - $comb_idx + 1;

    #here the integral of f(x) = x -> F(x) = 1/2 x^2 -> F(y) = sqrt(2x) with a small correction of 0.5
    my $raw_row = int( sqrt( 2 * $k ) - 0.5 );
    #-2 -> index corrections
    my $real_row = $idx_num_elem - $raw_row - 2;

    #now we have the row, time for the column
    my $inv_row  = $idx_num_elem - $real_row - 1;
    my $raw_col  = $num_comb - ( ( $inv_row + 1 ) * $inv_row ) / 2;
    my $real_col = $comb_idx - $raw_col + $real_row;

    return ( $real_row, $real_col );
}

sub cur_comb {
    my ($self) = @_;

    #we did not start yet.
    return if ( $self->cur_comb_idx == BEYOND_LAST_ELEMENT );

    my ( $row_idx, $col_idx ) = $self->_position( $self->cur_comb_idx +1 );

    return [ $self->indices->[0]->get_elem($row_idx), $self->indices->[0]->get_elem($col_idx) ];
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
