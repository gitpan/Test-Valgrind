#!perl

use strict;
use warnings;

use Test::More tests => 4;

use Test::Valgrind::Command;
use Test::Valgrind::Tool;
use Test::Valgrind::Action;
use Test::Valgrind::Session;

my $cmd = Test::Valgrind::Command->new(
 command => 'Perl',
 args    => [ ],
);

my $tool = Test::Valgrind::Tool->new(
 tool => 'memcheck',
);

my $sess = Test::Valgrind::Session->new(
 min_version => $tool->requires_version,
);

$sess->command($cmd);
$sess->tool($tool);

my $file = $sess->def_supp_file;

like($file, qr!\Q$Test::Valgrind::Session::VERSION\E/memcheck-\d+(?:\.\d+)*-[0-9a-f]{32}\.supp$!, 'suppression file is correctly named');
ok(-e $file, 'suppression file exists');
ok(-r $file, 'suppression file is readable');

if (not open my $supp, '<', $file) {
 fail("Couldn't open the suppression file at $file: $!");
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
