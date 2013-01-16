package Action::Retry::Strategy::HelperRole::RetriesLimit;

# ABSTRACT: Helper to be consumed by Action::Retry Strategies, to enable giving up retrying after a number of retries

use namespace::autoclean;
use Moo::Role;

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

around needs_to_retry => sub {
    my $orig = shift;
    my $self = shift;
    defined $self->max_retries_number
      or return $orig->($self, @_);
    $orig->($self, @_) && $self->_current_retries_number < $self->max_retries_number
};

after next_step => sub {
    my ($self) = @_;
    $self->_current_retries_number($self->_current_retries_number + 1);
};

after reset => sub {
    my ($self) = @_;
    $self->_clear_current_retries_number;
};

1;
