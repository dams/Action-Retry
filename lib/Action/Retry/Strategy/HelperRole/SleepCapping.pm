package Action::Retry::Strategy::HelperRole::SleepCapping;

# ABSTRACT: Helper to be consumed by Action::Retry Strategies, to enable capping the sleep time

use Moo::Role;

use List::Util qw(min);

has capped_sleep_time => (
    is => 'ro',
    lazy => 1,
    default => sub { undef },
);

around compute_sleep_time => sub {
    my $orig = shift;
    my $self = shift;
    
    return defined $self->capped_sleep_time
      ? min($orig->($self, @_), $self->capped_sleep_time)
      : $orig->($self, @_);

};

1;
