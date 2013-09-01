
# ABSTRACT: Linear incrementation of sleep time strategy

# PODNAME: Action::Retry::Strategy::Linear
package Action::Retry::Strategy::Linear;

use namespace::autoclean;
use mop;

class Action::Retry::Strategy::Linear with Action::Retry::Strategy, Action::Retry::Strategy::HelperRole::RetriesLimit, Action::Retry::Strategy::HelperRole::SleepTimeout {

=head1 SYNOPSIS

To be used as strategy in L<Action::Retry>

=cut

=attr initial_sleep_time

  ro, Int, defaults to 1000 ( 1 second )

The number of milliseconds to wait for the first retry

=cut

has $!initial_sleep_time is ro, lazy = 1000;

# the current sleep time, as it's computed
has $!_current_sleep_time is rw, lazy = $_->initial_sleep_time;

method _clear_current_sleep_time { undef $!_current_sleep_time }

=attr multiplicator

  ro, Int, defaults to 2

Number multiplied by the last sleep time. E.g. if set to 2, the time between
two retries will double. If set to 1, it'll remain constant. Defaults to 2

=cut

has $!multiplicator is ro, lazy = 2;

method reset { $self->_clear_current_sleep_time }

method compute_sleep_time { $self->_current_sleep_time }

method next_step {
    $self->_current_sleep_time($self->_current_sleep_time * $self->multiplicator);
}

method needs_to_retry { 1 }

# Inherited from Action::Retry::Strategy::HelperRole::RetriesLimit

=attr max_retries_number

  ro, Int|Undef, defaults to 10

The number of times we should retry before giving up. If set to undef, never
stop retrying.

=cut

# Inherited from Action::Retry::Strategy::HelperRole::SleepTimeout

=attr max_sleep_time

  ro, Int|Undef, defaults to undef

If Action::Retry is about to sleep more than this number ( in milliseconds ),
stop retrying. If set to undef, never stop retrying.

=cut

}

1;
