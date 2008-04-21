#!perl -T

use strict;
use warnings;

use Test::More tests => 2;

require Test::Valgrind::Suppressions;

for (qw/supp_path VG_PATH/) {
 eval { Test::Valgrind::Suppressions->import($_) };
 ok(!$@, 'import ' . $_);
}
