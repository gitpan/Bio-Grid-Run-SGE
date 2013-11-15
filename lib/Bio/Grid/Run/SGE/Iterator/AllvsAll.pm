package Bio::Grid::Run::SGE::Iterator::AllvsAll;

use Mouse;

use warnings;
use strict;
use List::Util qw/reduce/;

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

sub cur_comb_coords {
    my ($self) = @_;
    
    #we did not start yet.
    return if ( $self->cur_comb_idx == BEYOND_LAST_ELEMENT );

    my $num_rows = $self->indices->[0]->num_elem;
    my $num_cols = $self->indices->[0]->num_elem;
    my $idx = $self->cur_comb_idx;

    my $row_idx = int($idx/$num_cols);
    my $col_idx = $idx % $num_cols;

    return ($row_idx, $col_idx);
}

sub cur_comb {
    my ($self) = @_;

    my ($row_idx, $col_idx) = $self->cur_comb_coords;

    return [ $self->indices->[0]->get_elem( $row_idx ), $self->indices->[0]->get_elem($col_idx) ];
}

sub num_comb {
    my ($self) = @_;

    return $self->indices->[0] ** 2;
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

Bio::Grid::Run::SGE::Iterator::AllvsAll - Iterate through two indices by combining all elements from the first with the second index.

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 OPTIONS

=head1 SUBROUTINES
=head1 METHODS

=head1 SEE ALSO

=head1 AUTHOR

jw bargsten, C<< <jwb at cpan dot org> >>

=cut
