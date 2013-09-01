
# ABSTRACT: Fibonacci incrementation of sleep time strategy

# PODNAME: Action::Retry::Strategy::Fibonacci

package Action::Retry::Strategy::Fibonacci;

use Math::Fibonacci qw(term);

use namespace::autoclean;
use mop;

class Action::Retry::Strategy::Fibonacci with Action::Retry::Strategy, Action::Retry::Strategy::HelperRole::RetriesLimit, Action::Retry::Strategy::HelperRole::SleepTimeout {

=head1 SYNOPSIS

To be used as strategy in L<Action::Retry>

=cut

=head1 DESCRIPTION

Sleeps incrementally by following the Fibonacci sequence : F(i) = F(i-1) +
F(i-2) starting from 0,1. By default F(0) = 0, F(1) = 1, F(2) = 1, F(3) = 2

=cut


=attr initial_term_index

  ro, Int, defaults to 0

Term number of the Fibonacci sequence to start at. Defaults to 0

=cut

has $!initial_term_index is ro, lazy = 0;

# the current sequence term index
has $!_current_term_index is rw, lazy = $_->initial_term_index;

method _clear_current_term_index { $self->_current_term_index(undef) }

=attr multiplicator

  ro, Int, defaults to 1000

Number of milliseconds that will be multiplied by the fibonacci sequence term
value. Defaults to 1000 ( 1 second )

=cut

has $!multiplicator is ro, lazy = 1000;

method reset { $self->_clear_current_term_index }

method compute_sleep_time { term($self->_current_term_index) * $!multiplicator }

method next_step {
    $self->_current_term_index($self->_current_term_index() + 1 )
}

method needs_to_retry { 1 }

# Inherited from Action::Retry::Strategy::HelperRole::RetriesLimit

=attr max_retries_number

  ro, Int, defaults to 10

The number of times we should retry before giving up. If set to undef, never stop retrying

=cut

# Inherited from Action::Retry::Strategy::HelperRole::SleepTimeout

=attr max_sleep_time

  ro, Int|Undef, defaults to undef

If Action::Retry is about to sleep more than this number ( in milliseconds ),
stop retrying. If set to undef, never stop retrying

=cut

}

1;
