
# PODNAME: Action::Retry::Strategy

# ABSTRACT: Srategy role that any Action::Retry strategy should consume

use mop;

role Action::Retry::Strategy {
    method needs_to_retry;
    method compute_sleep_time;
    method next_step;
    method reset;
}

1;
