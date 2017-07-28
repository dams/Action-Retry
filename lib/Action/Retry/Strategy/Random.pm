package Action::Retry::Strategy::Random;

# ABSTRACT: Random sleep time strategy

use Moo;

=head1 SYNOPSIS

To be used as strategy in L<Action::Retry>. For motivation, see the
C<--random-wait> option of the C<wget> command.

=cut

with
    'Action::Retry::Strategy',
    'Action::Retry::Strategy::HelperRole::RetriesLimit';

=attr time_min

    ro, Int, defaults to 1000 (1 second).

The minimal number of milliseconds to wait.

=cut

has time_min => (
    is => 'ro',
    default => 1000,
);

=attr time_max

    ro, Int, defaults to 5000 (5 seconds).

The maximal number of milliseconds to wait.

=cut

has time_max => (
    is => 'ro',
    default => 5000,
);

# the current sleep time, as it's computed
has _current_sleep_time => (
    is => 'rw',
    lazy => 1,
    default => sub { $_[0]->_random_time },
    init_arg => undef,
);

sub _random_time {
    my ($self) = @_;
    return $self->time_min + int rand($self->time_max - $self->time_min + 1);
}

sub compute_sleep_time {
    my ($self) = @_;
    return $self->_current_sleep_time;
}

sub next_step {
    my ($self) = @_;
    $self->_current_sleep_time($self->_random_time);
    return;
}

sub reset { return }

sub needs_to_retry { 1 }

# Inherited from Action::Retry::Strategy::HelperRole::RetriesLimit

=attr max_retries_number

  ro, Int|Undef, defaults to 10

The number of times we should retry before giving up. If set to undef, never
stop retrying.

=cut

1;
