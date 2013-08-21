# PODNAME: Action::Retry::Strategy::HelperRole::RetriesLimit
# ABSTRACT: Helper to be consumed by Action::Retry Strategies, to enable giving up retrying after a number of retries

package Action::Retry::Strategy::HelperRole::RetriesLimit;

use mop;

sub modifier {
    if ($_[0]->isa('mop::method')) {
        my $method = shift;
        my $type   = shift;
        my $meta   = $method->associated_meta;
        if ($meta->isa('mop::role')) {
            if ( $type eq 'around' ) {
                $meta->bind('after:COMPOSE' => sub {
                    my ($self, $other) = @_;
                    use Data::Dumper;
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

role Action::Retry::Strategy::HelperRole::RetriesLimit {

has $max_retries_number is ro = 10;

# the current number of retries
has $_current_retries_number is rw = 0;

method needs_to_retry is modifier('around') {
    defined $self->max_retries_number
      or return $self->${^NEXT}(@_);
    $self->${^NEXT}(@_) && $self->_current_retries_number < $self->max_retries_number;
}

method next_step is modifier('around') {
    $self->${^NEXT}(@_);
    $self->_current_retries_number($self->_current_retries_number + 1);
}

method reset is modifier('around') {
    $self->${^NEXT}(@_);
    $self->_current_retries_number(0);
}

}

1;
