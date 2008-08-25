use strict;
use warnings;

my ($sf) = @ARGV;
exit 1 unless defined $sf;

my $file = './gen.pl';

pipe my $rdr, my $wtr or die "pipe(\$rdr, \$wtr): $!";
my $pid = fork;
if (!defined $pid) {
 die "fork(): $!";
} elsif ($pid == 0) {
 close $rdr or die "close(\$rdr): $!";
 open STDERR, '>&', $wtr or die "open(STDERR, '>&', \$wtr): $!";
 exec $^X, '-Mlib=lib', $file;
}
close $wtr or die "close(\$rdr): $!";

my ($s, $in, @supps) = ('', 0);
while (<$rdr>) {
 s/^\s*#\s//;
 next if /^==/;
 next if /valgrind/ and /\Q$file\E/;
 s/^\s*//;
 s/<[^>]+>//;
 s/\s*$//;
 next unless length;
 if ($_ eq '{') {
  $in = 1;
 } elsif ($_ eq '}') {
  push @supps, $s;
  $s  = '';
  $in = 0;
 } elsif ($in) {
  $s .= "$_\n";
 }
}
waitpid $pid, 0;

select STDERR;

my $a = @supps;
print "Found $a suppressions\n";

my @extra;
for (@supps) {
 if (/\bfun:(m|c|re)alloc\b/) {
  my $t = $1;
  my %call;
  if ($t eq 'm') { # malloc can also be called by calloc or realloc
   $call{$_} = 1 for qw/calloc realloc/;
  } elsif ($t eq 're') { # realloc can also call malloc or free
   $call{$_} = 0 for qw/malloc free/;
  } elsif ($t eq 'c') { # calloc can also call malloc
   $call{$_} = 0 for qw/malloc/;
  }
  my $c = $_;
  for (keys %call) {
   my $d = $c;
   $d =~ s/\b(fun:${t}alloc)\b/$call{$_} ? "$1\nfun:$_" : "fun:$_\n$1"/e;
   # Remove one line for each line added or valgrind will hate us
   $d =~ s/\n(.+?)\s*$/\n/;
   push @extra, $d;
  }
 }
}
my $e = @extra;
print "Generated $e extra suppressions\n";

my %dupes;
@dupes{@supps, @extra} = ();
@supps = keys %dupes;
my $b = @supps;
print "Removed " . (($a + $e) - $b) . " duplicates\n";

my ($name, $num) = ('perlTestValgrind', 0);

1 while unlink $sf;

open my $out, '>', $sf or die "$!";
print $out "{\n$name" . (++$num) . "\n$_}\n" for @supps;
close $out;
