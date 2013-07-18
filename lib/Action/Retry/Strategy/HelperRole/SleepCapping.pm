# PODNAME: Action::Retry::Strategy::HelperRole::SleepCapping;

# ABSTRACT: Helper to be consumed by Action::Retry Strategies, to enable capping the sleep time

use mop;
use List::Util qw(min);

sub modifier {
    if ($_[0]->isa('mop::method')) {
        my $method = shift;
        my $type   = shift;
        my $meta   = $method->associated_meta;
        if ($meta->isa('mop::role')) {
            if ( $type eq 'around' ) {
                $meta->bind('after:COMPOSE' => sub {
                    my ($self, $other) = @_;
                    if ($other->has_method( $method->name )) {
                        my $old_method = $other->remove_method( $method->name );
                        $other->add_method(
                            $other->method_class->new(
                                name => $method->name,
                                body => sub {
                                    local ${^NEXT} = $old_method->body;
                                    my $self = shift;
                                    $method->execute( $self, [ @_ ] );
                                }
                            )
                        );
                    }
                });
            } elsif ( $type eq 'before' ) {
                die "before not yet supported";
            } elsif ( $type eq 'after' ) {
                die "after not yet supported";    
            } else {
                die "I have no idea what to do with $type";
            }
        } elsif ($meta->isa('mop::class')) {
            die "modifiers on classes not yet supported";
        }
    }
}

role Action::Retry::Strategy::HelperRole::SleepCapping {

has $capped_sleep_time is ro = undef;

method compute_sleep_time is modifier('around') {
    return defined $capped_sleep_time
      ? min(${^NEXT}->(@_), $capped_sleep_time)
      : ${^NEXT}->(@_);

}

}

1;
