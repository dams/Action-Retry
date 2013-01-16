package Action::Retry::Strategy;

# ABSTRACT: Srategy role that any Action::Retry strategy should consume

use namespace::autoclean;
use Moo::Role;

requires 'needs_to_retry';
requires 'sleep_time';
requires 'next_step';
requires 'reset';

1;
