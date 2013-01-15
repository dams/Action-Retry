package Action::Retry;

# ABSTRACT: Module to try to perform an action, with various ways of retrying and sleeping between retries.

use Module::Runtime qw(use_module);
use Scalar::Util qw(blessed);
use Time::HiRes qw( usleep );

use namespace::autoclean;
use Moo;

=head1 SYNOPSIS

  use Action::Retry;
  my $action = Action::Retry->new(
    attempt_code => sub { ... },
    strategy => 'Linear',
  );
  $action->run();

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

The strategy for managing retrying times, sleeping, and giving up. It must be
an object that does the L<Action::Retry::Strategy> role.

This attribute has a coercion from strings and hashrefs. If you pass a string,
it will be treated as a class name (under C<Action::Retry::Strategy::>, unless
it is prefxed with a C<+>) to instantiate.

If you pass a hashref, the first key will be treated as a class name as above,
and the value of that key will be treated as the args to pass to C<new>.

Some existing stragies classes are L<Action::Retry::Strategy::Constant>,
L<Action::Retry::Strategy::Fibonacci>, L<Action::Retry::Strategy::Linear>.

=cut

has strategy => (
    is => 'ro',
    required => 1,
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
    isa => sub { $_[0]->does('Action::Retry::Strategy') or die 'Should consume the Action::Retry::Strategy role' },
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

    $self->strategy->reset;

    while(1) {
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
          or return @attempt_result;

        if (! $self->strategy->needs_to_retry) {
            $self->has_on_failure_code
              and return $self->on_failure_code->($@, @attempt_result);
            return;
        }

        usleep($self->strategy->sleep_time);
        $self->strategy->next_step;
    }
}

1;
