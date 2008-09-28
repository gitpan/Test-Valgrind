#!perl

use strict;
use warnings;

use Test::More;
use lib qw{blib/archpub};
eval { use Test::Valgrind };
if ($@) {
 diag $@;
 plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind';
}

plan tests => 1;
fail('bogus failure, don\'t worry');
