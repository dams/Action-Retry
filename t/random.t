use Action::Retry qw(retry);

use strict;
use warnings;

use Test::More tests => 3 + 2;
use Time::HiRes;

srand 42;

{
   my $EXPECTED_TOTAL_TIME = 555;
   my $LAST_TRY_TIME = 52;
   my $total_time;

   my $action;
   $action = Action::Retry->new(
       attempt_code => sub { $total_time += $action->strategy->_current_sleep_time; die "plop" },
       strategy => { Random => {
           time_min => 10,
           time_max => 100,
       } },
   );

   my $t0 = 1000 * Time::HiRes::time();
   $action->run();
   my $t1 = 1000 * Time::HiRes::time();

   is($total_time, $EXPECTED_TOTAL_TIME + $LAST_TRY_TIME, 'sum of all times');
   my $tolerance = 50;
   cmp_ok($t1 - $t0, '<', $EXPECTED_TOTAL_TIME + $tolerance, 'real time lower bound');
   cmp_ok($t1 - $t0, '>', $EXPECTED_TOTAL_TIME - $tolerance, 'real time upper bound');
}

{
   my ($from, $to) = (10, 12);

   my %seen_times;
   my $action;
   $action = Action::Retry->new(
       attempt_code => sub {
           my $t = $action->strategy->_current_sleep_time;
           undef $seen_times{$t};
           die "plop";
       },
       strategy => { Random => {
           time_min => $from,
           time_max => $to,
           max_retries_number => 10,
       } },
   );

   $action->run();

   is(keys %seen_times, $to - $from + 1, 'correct number of times');

   delete @seen_times{ $from .. $to };
   ok(! keys %seen_times, 'no invalid times');
}

done_testing();
