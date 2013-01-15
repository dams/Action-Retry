package Action::Retry::Strategy;

use namespace::autoclean;
use Moo::Role;

requires 'needs_to_retry';
requires 'next_step';
requires 'reset';


1;
