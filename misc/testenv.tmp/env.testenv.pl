#!/usr/bin/env perl
use warnings;
use strict;

my $cmd = shift;
unless ( my $return = do $cmd ) {
  warn "could not parse $cmd $@" if $@;
  warn "could not do $cmd $!" unless defined $return;
  warn "could not run $cmd" unless $return;
}
exit;
