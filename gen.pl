#!perl

use strict;
use warnings;

use Test::More;
eval <<'EOD';
use Test::Valgrind diag => 1,
                   no_test => 1,
                   no_supp => 1,
                   extra => [
                    q{--show-reachable=yes},
                    q{--gen-suppressions=all},
#                    q{--log-fd=1}
                   ]
EOD
plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind' if $@;

1;

