package Action::Retry::Strategy::HelperRole::SleepTimeout;

# ABSTRACT: Helper to be consumed by Action::Retry Strategies, to enable giving up retrying when the sleep_time is too big

use Moo::Role;

has max_sleep_time => (
    is => 'ro',
    lazy => 1,
    default => sub { undef },
);

around needs_to_retry => sub {
    my $orig = shift;
    my $self = shift;
    defined $self->max_sleep_time
      or return $orig->($self, @_);
    $orig->($self, @_) && $self->compute_sleep_time < $self->max_sleep_time
};

1;
