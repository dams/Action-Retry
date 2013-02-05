use Action::Retry qw(retry);

use strict;
use warnings;

use Test::Most;
use Test::Pretty;

{
    my $var = 0;
    my $acc = 0;
    my $action = Action::Retry->new(
        attempt_code => sub { my ($val) = @_; $acc+=$val; $var++; die "plop" },
        strategy => { Fibonacci => { initial_term_index => 0, multiplicator => 10 } },
    );
    $action->run(2);
    is($var, 11);
    is($acc, 22);
}

{
    my $var = 0;
    retry { $var++; die "plop"; }
        strategy => { Fibonacci => { initial_term_index => 0, multiplicator => 10 } };
    is($var, 11);
}

{
    my $var = 0;
    my $action = Action::Retry->new(
        attempt_code => sub { $var++; die "plop" },
        strategy => { Fibonacci => { initial_term_index => 0,
                                     multiplicator => 10,
                                     max_sleep_time => 200,
                                   } },
    );
    $action->run();
    is($var, 9);
}

{
    my $var = 0;
    retry { $var++; die "plop" }
        strategy => { Fibonacci => { initial_term_index => 0,
                                     multiplicator => 10,
                                     max_sleep_time => 200,
                                   } };
    is($var, 9);
}

done_testing;
