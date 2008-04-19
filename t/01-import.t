#!perl -T

use strict;
use warnings;

use Test::More tests => 1;

require Test::Valgrind::Suppressions;

for (qw/supppath/) {
 eval { Test::Valgrind::Suppressions->import($_) };
 ok(!$@, 'import ' . $_);
}
