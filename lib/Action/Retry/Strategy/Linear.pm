package Action::Retry::Strategy::Linear;

use namespace::autoclean;
use Moo;

=head1 SYNOPSIS

To be used as strategy in L<Action::Retry>

=cut

with 'Action::Retry::Strategy';

=attr initial_sleep_time

  ro, Int, defaults to 1000

The number of microseconds to wait for the first retry

=cut

has initial_sleep_time => (
    is => 'ro',
    lazy => 1,
    default => sub { 1000 },
);

# the current sleep time, as it's computed
has _current_sleep_time => (
    is => 'rw',
    lazy => 1,
    default => sub { $_[0]->initial_sleep_time },
    init_arg => undef,
    clearer => 1,
    handles => [ qw(sleep_time) ],
);

=attr multiplicator

  ro, Int, defaults to 2

Number multiplied by the last sleep time. E.g. if set to 2, the time between
two retries will double. If set to 1, it'll remain constant. Defaults to 2

=cut

has multiplicator => (
    is => 'ro',
    lazy => 1,
    default => sub { 2 },
);

=attr max_retries_number

  ro, Int, defaults to 10

The number of times we should retry before giving up

=cut

has max_retries_number => (
    is => 'ro',
    lazy => 1,
    default => sub { 10 },
);

# the current number of retries
has _current_retries_number => (
    is => 'rw',
    lazy => 1,
    default => sub { 0 },
    init_arg => undef,
    clearer => 1,
);

sub reset {
    my ($self) = @_;
    $self->_clear_current_sleep_time;
    $self->_clear_current_retries_number;
    return;
};

sub next_step {
    my ($self) = @_;
    $self->_current_sleep_time($self->_current_sleep_time * $self->multiplicator);
    $self->_current_retries_number($self->_current_retries_number + 1);
    return;
};

sub needs_to_retry {
    my ($self) = @_;
    return $self->_current_retries_number < $self->max_retries_number;
}

1;
