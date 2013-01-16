package Action::Retry::Strategy::Fibonacci;

# ABSTRACT: Fibonacci incrementation of sleep time strategy

use Math::Fibonacci qw(term);

use namespace::autoclean;
use Moo;

=head1 SYNOPSIS

To be used as strategy in L<Action::Retry>

=cut

=head1 DESCRIPTION

Sleeps incrementally by following the Fibonacci sequence : F(i) = F(i-1) +
F(i-2) starting from 0,1.

=cut

with 'Action::Retry::Strategy';
with 'Action::Retry::Strategy::HelperRole::RetriesLimit';
with 'Action::Retry::Strategy::HelperRole::SleepTimeLimit';

=attr initial_term_index

  ro, Int, defaults to 0

Term number of the Fibonacci sequence to start at. Defaults to 0

=cut

has initial_term_index => (
    is => 'ro',
    lazy => 1,
    init_arg => undef,
    default => sub { 0 },
);

# the current sequence term index
has _current_term_index => (
    is => 'rw',
    lazy => 1,
    default => sub { $_[0]->initial_term_index },
    init_arg => undef,
    clearer => 1,
);


=attr multiplicator

  ro, Int, defaults to 1000

Number of milliseconds that will be multiplied by the fibonacci sequence term
value. Defaults to 1000 ( 1 second)

=cut

has multiplicator => (
    is => 'ro',
    lazy => 1,
    default => sub { 1000 },
);

sub reset {
    my ($self) = @_;
    $self->_clear_current_term_index;
    return;
};

sub sleep_time {
    my ($self) = @_;
#    print STDERR " -- sleep time is " . term($self->_current_term_index) * $self->multiplicator . "\n";
    return term($self->_current_term_index) * $self->multiplicator;
}

sub next_step {
    my ($self) = @_;
    $self->_current_term_index($self->_current_term_index + 1);
    return;
};

sub needs_to_retry { 1 }

# Inherited from Action::Retry::Strategy::HelperRole::RetriesLimit

=attr max_retries_number

  ro, Int, defaults to 10

The number of times we should retry before giving up

=cut

# Inherited from Action::Retry::Strategy::HelperRole::SleepTimeLimit

=attr max_sleep_time

  ro, Int|Undef, defaults to undef

If Action::Retry is about to sleep more than this number ( in milliseconds ),
stop retrying.

=cut

1;
