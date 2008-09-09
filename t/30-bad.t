#!perl

use strict;
use warnings;

use Config qw/%Config/;

use Test::More;

sub tester {
 my ($a, $desc) = @_;
 my $passed;
 my $dbg = eval "Test::Valgrind::DEBUGGING()";
 if ($desc =~ /still\s+reachable/) {
  $passed = $a >= 9900 && $a < 10100;
  if ($dbg) {
   ok($passed, $desc);
  } else {
   TODO: {
    local $TODO = "Leak count may be off on non-debugging perls";
    ok($passed, $desc);
   }
   return 1;
  }
 } else {
  $passed = defined $a && $a == 0;
  is($a, 0, $desc);
 }
 return $passed;
}

eval "
 require XSLoader;
 XSLoader::load('Test::Valgrind', 0.06);
";
if ($@) {
 plan skip_all => "XS test code not available ($@)";
} else {
 use lib qw{blib/archpub};
 eval 'use Test::Valgrind cb => \&tester;';
 if ($@) {
  plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind';
 } else {
  Test::Valgrind::leak();
 }
}
