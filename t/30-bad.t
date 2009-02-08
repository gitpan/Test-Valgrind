#!perl

use strict;
use warnings;

use Test::More;

my $dbg;

sub tester {
 my ($a, $desc) = @_;
 my $passed;
 if (!defined $dbg) {
  eval "
   use lib qw{blib/arch};
   require XSLoader;
   XSLoader::load('Test::Valgrind', \$Test::Valgrind::VERSION);
  ";
  if ($@) {
   my $err = $@;
   $dbg = 0;
   chomp $err;
   diag "XS test code not available ($err)";
  } else {
   my $ret = eval "Test::Valgrind::DEBUGGING()";
   $dbg = $@ ? 0 : $ret;
  }
 }
 if ($desc =~ /definitely\s+lost/) {
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

use lib qw{blib/archpub};
eval 'use Test::Valgrind cb => \&tester';
if ($@) {
 diag $@;
 plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind';
} else {
 eval "
  use lib qw{blib/arch};
  require XSLoader;
  XSLoader::load('Test::Valgrind', \$Test::Valgrind::VERSION);
 ";
 unless ($@) {
  Test::Valgrind::leak();
 }
}
