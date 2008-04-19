#!perl

use strict;
use warnings;

use Test::More;
eval 'use Test::Valgrind'; # diag => 1';
plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind' if $@;

1;
