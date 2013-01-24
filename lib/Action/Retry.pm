package Action::Retry;

# ABSTRACT: Module to try to perform an action, with various ways of retrying and sleeping between retries.

use Module::Runtime qw(use_module);
use Scalar::Util qw(blessed);
use Time::HiRes qw(usleep gettimeofday);
use Carp;

use Sub::Exporter -setup => { exports => [ qw(retry) ] };

use namespace::autoclean;
use Moo;

=head1 SYNOPSIS

  # Simple usage, will attempt to run the code, retrying if it dies, retrying
  # 10 times max, sleeping 1 second between retries

  # functional interface
  use Action::Retry qw(retry);
  retry { do_stuff };
 
  # OO interface
  use Action::Retry;
  Action::Retry->new( attempt_code => sub { do_stuff; } )->run();



  # Same, but sleep time is doubling each time

  # OO interface
  my $action = Action::Retry->new(
    attempt_code => sub { ... },
    strategy => 'Linear',
  );
  $action->run();

  # functional interface
  retry { ... }, strategy => 'Linear';



  # Same, but sleep time is following the Fibonacci sequence

  # OO interface
  my $action = Action::Retry->new(
    attempt_code => sub { ... },
    strategy => 'Fibonacci',
  );
  $action->run();

  # functional interface
  retry { ... }, strategy => 'Fibonacci';



  # The code to check if the attempt succeeded can be customized. Strategies
  # can take arguments. Code on failure can be specified.

  # OO way
  my $action = Action::Retry->new(
    attempt_code => sub { ... },
    retry_if_code => sub { $_[0] =~ /Connection lost/ || $_[1] > 20 },
    strategy => { Fibonacci => { multiplicator => 2000,
                                 initial_term_index => 3,
                                 max_retries_number => 5,
                               }
                },
    on_failure_code => sub { say "Given up retrying" },
  );
  $action->run();

  # functional way
  retry { ...},
    retry_if_code => sub { ... },
    strategy => { Fibonacci => { multiplicator => 2000,
                                 initial_term_index => 3,
                                 max_retries_number => 5,
                               }
                },
    on_failure_code => sub { ... };



  # Retry code in non-blocking way

  # OO way
  my $action = Action::Retry->new(
    attempt_code => sub { ...},
    non_blocking => 1,
  );
  while (1) {
    # if the action failed, it doesn't sleep
    # next time it's called, it won't do anything until it's time to retry
    $action->run();
    # do something else while time goes on
  }

  There is no functional way of doing that, for now.


=cut

=attr attempt_code

  ro, CodeRef, required

The code to run to attempt doing the action. Will be evaluated taking care of
the caller's context.

=cut

has attempt_code => (
    is => 'ro',
    required => 1,
    isa => sub { ref $_[0] eq 'CODE' },
);

=attr retry_if_code

  ro, CodeRef

The code to run to check if we need to retry the action. It will be given as
first argument, $@, then as following arguments the return values of the
execution of C<attempt_code>.

True return value means the execution of C<attempt_code> was a failure and it
needs to be retried. False means it went well.

Defaults to:

  # Returns true if there were an exception evaluating to something true
  sub { $_[0] }

=cut

has retry_if_code => (
    is => 'ro',
    required => 1,
    isa => sub { ref $_[0] eq 'CODE' },
    default => sub { sub { $_[0] }; },
);

=attr on_failure_code

  ro, CodeRef, optional

If given, the code to run when retries are given up.

=cut

has on_failure_code => (
    is => 'ro',
    isa => sub { ref $_[0] eq 'CODE' },
    predicate => 1,
);

=attr strategy

  ro, defaults to 'Constant'

The strategy for managing retrying times, sleeping, and giving up. It must be
an object that does the L<Action::Retry::Strategy> role.

This attribute has a coercion from strings and hashrefs. If you pass a string,
it will be treated as a class name (under C<Action::Retry::Strategy::>, unless
it is prefxed with a C<+>) to instantiate.

If you pass a hashref, the first key will be treated as a class name as above,
and the value of that key will be treated as the args to pass to C<new>.

Some existing stragies classes are L<Action::Retry::Strategy::Constant>,
L<Action::Retry::Strategy::Fibonacci>, L<Action::Retry::Strategy::Linear>.

Defaults to C<'Constant'>

=cut

has strategy => (
    is => 'ro',
    defaults => sub { 'Constant' },
    coerce => sub {
        my $attr = $_[0];
        blessed($attr)
          and return $attr;
        my $class_name = $attr;
        my $constructor_params = {};
        if (ref $attr eq 'HASH') {
            $class_name = (keys %$attr)[0];
            $constructor_params = $attr->{$class_name};
        }
        $class_name = $class_name =~ /^\+(.+)$/ ? $1 : "Action::Retry::Strategy::$class_name";
        return use_module($class_name)->new($constructor_params);
    },
    isa => sub { $_[0]->does('Action::Retry::Strategy') or croak 'Should consume the Action::Retry::Strategy role' },
);

=attr non_blocking

  ro, defaults to 0

If true, the instance will be in a pseudo non blocking mode. In this mode, the
C<run()> function behaves a bit differently: instead of sleeping between
retries, the C<run()> command will immediately return. Subsequent call to
C<run()> will immediately return, until the time to sleep has been elapsed.
This allows to do things like that:

  my $action = Action::Retry->new( ... , non_blocking => 1 );
  while (1) {
    # if the action failed, it doesn't sleep
    # next time it's called, it won't do anything until it's time to retry
    $action->run();
    # do something else while time goes on
  }

If you need a more advanced non blocking mode and callbacks, then look at L<AnyEvent::Retry>

=cut

has non_blocking => (
    is => 'ro',
    default => sub { 0 },
);

# For non blocking mode, store the timestamp after which we can retry
has _needs_sleeping_until => (
    is => 'rw',
    default => sub { 0 },
    init_arg => undef,
);

=method run

Does the following:

=over

=item step 1

Runs the C<attempt_code> CodeRef in the proper context in an eval {} block,
saving C<$@> in C<$error>.

=item step 2

Runs the C<retry_if_code> CodeRef in scalar context, giving it as arguments
C<$error>, and the return values of C<attempt_code>. If it returns true, we
consider that it was a failure, and move to step 3. Otherwise, we consider it
means success, and return the return values of C<attempt_code>.

=item step 3

Ask the C<strategy> if it's still useful to retry. If yes, sleep accordingly,
and go back to step 2. If not, go to step 4.

=item step 4

Runs the C<on_failure_code> CodeRef in the proper context, giving it as
arguments C<$error>, and the return values of C<attempt_code>, and returns the
results back to the caller.

=back

=cut

sub run {
    my ($self) = @_;

    while(1) {

        if (my $timestamp = $self->_needs_sleeping_until) {
            # we can't retry until we have waited enough time 
            my ($seconds, $microseconds) = gettimeofday;
            $seconds * 1000 + int($microseconds / 1000) >= $timestamp
              or return;
            $self->_needs_sleeping_until(0);
            $self->strategy->next_step;
        }

        my $error;
        my @attempt_result;
          
        if (wantarray) {
            @attempt_result = eval { $self->attempt_code->() };
            $error = $@;
        } elsif ( ! defined wantarray ) {
            eval { $self->attempt_code->() };
            $error = $@;
        } else {
            my $scalar_result = eval { $self->attempt_code->() };
            $error = $@;
            @attempt_result = $scalar_result;
        }

        $self->retry_if_code->($error, @attempt_result)
          or $self->strategy->reset, return @attempt_result;

        if (! $self->strategy->needs_to_retry) {
            $self->strategy->reset;
            $self->has_on_failure_code
              and return $self->on_failure_code->($@, @attempt_result);
            return;
        }

        if ($self->non_blocking) {
            my ($seconds, $microseconds) = gettimeofday;
            $self->_needs_sleeping_until($seconds * 1000 + int($microseconds / 1000) + $self->strategy->compute_sleep_time);
        } else {
            usleep($self->strategy->compute_sleep_time * 1000);
            $self->strategy->next_step;
        }
    }
}

sub retry (&;@) {
    my $code = shift;
    @_ % 2
      and croak "arguments to retry must be a CodeRef, and an even number of key / values";
    my %args = @_;
    Action::Retry->new( attempt_code => $code, %args )->run();
}

=head1 SEE ALSO

I created this module because the other related modules I found didn't exactly
do what I wanted. Here is the list and why:

=over

=item L<Retry>

No custom checking code. No retry strategies. Can't sleep under one second. No
non-blocking mode. No custom failure code.

=item L<Sub::Retry>

No retry strategies. Can't sleep under one second. Retry code is
passed the results of the attempt code, but not the exception. No non-blocking mode. No custom failure code.

=item Attempt

No custom checking code. Strange exception catching behavior. No retry strategies. No non-blocking mode. No custom failure code.

=item AnyEvent::Retry

Depends on AnyEvent, and Moose. Strategies are less flexibles, and they don't have sleep timeouts (only max tries).

=back

=cut

1;
