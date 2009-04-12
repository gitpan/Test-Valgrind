#!perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';
eval 'use Test::Valgrind';
if ($@) {
 diag $@;
 plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind';
}

{
 package Test::Valgrind::Test::Fake;

 use base qw/strict/;
}

plan tests => 1;
fail 'should not be seen';
