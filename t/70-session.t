#!perl

use strict;
use warnings;

use Test::Valgrind::Session;

use File::Temp;

use Test::More tests => 7;

my $sess = eval { Test::Valgrind::Session->new(
 search_dirs => [ ],
) };
like $@, qr/^Empty valgrind candidates list/, 'no search_dirs';

$sess = eval { Test::Valgrind::Session->new(
 valgrind => 'wut',
) };
like $@, qr/^No appropriate valgrind executable/, 'nonexistant valgrind';

sub fake_vg {
 my ($version) = @_;
 return <<" FAKE_VG";
#!$^X
if (\@ARGV == 1 && \$ARGV[0] eq '--version') {
 print "valgrind-$version\n";
} else {
 print "hlagh\n";
}
 FAKE_VG
}

SKIP: {
 skip 'Only on linux' => 5 unless $^O eq 'linux';

 my $vg_old = File::Temp->new(UNLINK => 1);
 print $vg_old fake_vg('3.0.0');
 close $vg_old;
 chmod 0755, $vg_old->filename;

 my $sess = eval { Test::Valgrind::Session->new(
  valgrind    => $vg_old->filename,
  min_version => '3.1.0',
 ) };
 like $@, qr/^No appropriate valgrind executable/, 'old valgrind';

 my $vg_new = File::Temp->new(UNLINK => 1);
 print $vg_new fake_vg('3.4.0');
 close $vg_new;
 chmod 0755, $vg_new->filename;

 $sess = eval { Test::Valgrind::Session->new(
  valgrind    => $vg_new->filename,
  min_version => '3.1.0',
 ) };
 is     $@,    '',                        'new valgrind';
 isa_ok $sess, 'Test::Valgrind::Session', 'new valgrind isa Test::Valgrind::Session';

 $sess = eval { Test::Valgrind::Session->new(
  search_dirs => [ ],
  valgrind    => [ $vg_old->filename, $vg_new->filename ],
  min_version => '3.1.0',
 ) };
 is     $@,    '',                        'old and new valgrind';
 isa_ok $sess, 'Test::Valgrind::Session', 'old and new valgrind isa Test::Valgrind::Session';
}
