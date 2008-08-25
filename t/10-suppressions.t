#!perl -T

use strict;
use warnings;
use Test::More tests => 2;

use lib qw{blib/archpub};
use Test::Valgrind::Suppressions qw/supp_path VG_PATH/;

my $path = supp_path();
like($path, qr!Test/Valgrind/perlTestValgrind\.supp$!,
     'supppath() returns the path to the suppression file');

isnt(VG_PATH, undef, 'VG_PATH is defined');
