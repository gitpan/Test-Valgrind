#!perl -T

use strict;
use warnings;
use Test::More tests => 1;

use Test::Valgrind::Suppressions qw/supppath/;

my $path = supppath();
like($path, qr!Test/Valgrind/perlTestValgrind\.supp$!,
     'supppath() returns the path to the suppression file');
