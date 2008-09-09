#!perl

use strict;
use warnings;

use Test::More;
use lib qw{blib/archpub};
eval { use Test::Valgrind };
plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind' if $@;

1;
