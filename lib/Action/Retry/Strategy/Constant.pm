# PODNAME: Action::Retry::Strategy::Constant
# ABSTRACT: Constant sleep time strategy

package Action::Retry::Strategy::Constant;

use mop;

class Action::Retry::Strategy::Constant with Action::Retry::Strategy, Action::Retry::Strategy::HelperRole::RetriesLimit {

=head1 SYNOPSIS

To be used as strategy in L<Action::Retry>

=cut


=attr sleep_time

  ro, Int, defaults to 1000 ( 1 second )

The number of milliseconds to wait between retries

=cut

has $sleep_time is ro = 1000;

method compute_sleep_time { $sleep_time }

method reset { return }

method next_step { return }

method needs_to_retry { 1 }

# Inherited from Action::Retry::Strategy::HelperRole::RetriesLimit

=attr max_retries_number

  ro, Int|Undef, defaults to 10

The number of times we should retry before giving up. If set to undef, never
stop retrying

=cut

}

1;
