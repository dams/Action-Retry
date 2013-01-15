use Action::Retry;

use strict;
use warnings;

use Test::Most;
use Test::Pretty;

my $var = 0;
my $action = Action::Retry->new(
    attempt_code => sub { $var++; die "plop" },
    strategy => { Linear => { initial_sleep_time => 0 } },
);
$action->run();
is($var, 11);

done_testing;
