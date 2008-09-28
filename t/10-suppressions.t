#!perl -T

use strict;
use warnings;
use Test::More tests => 3;

use lib qw{blib/archpub};
use Test::Valgrind::Suppressions qw/supp_path VG_PATH/;

my $path = supp_path();
like($path, qr!Test/Valgrind/perlTestValgrind\.supp$!,
     'supppath() returns the path to the suppression file');

isnt(VG_PATH, undef, 'VG_PATH is defined');

if (not open my $supp, '<', $path) {
 fail("Couldn't open the suppression file at $path: $!");
} else {
 pass("Could open the suppression file");
 my ($in, $count, $true, $line) = (0, 0, 0, 0);
 while (<$supp>) {
  ++$line;
  chomp;
  s/^\s*//;
  s/\s*$//;
  if (!$in && $_ eq '{') {
   $in = $line;
  } elsif ($in && $_ eq '}') {
   ++$count;
   ++$true if $line - $in >= 2;
   $in = 0;
  }
 }
 diag "$count suppressions, of which $true are not empty";
 close $supp;
}
