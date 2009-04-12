#!perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';
eval 'use Test::Valgrind action => q[Test::Valgrind::Test::Action]';
if ($@) {
 diag $@;
 plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind';
}

eval {
 require XSLoader;
 XSLoader::load('Test::Valgrind', $Test::Valgrind::VERSION);
};

unless ($@) {
 Test::Valgrind::leak();
} else {
 diag $@;
}
