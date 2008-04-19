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

my ($supp, $name, $num) = ('', 'perlTestValgrind', 0);
while (<$rdr>) {
 s/^\s*#\s//;
 next if /^==/;
 next if /valgrind/ and /\Q$file\E/;
 s/<[^>]+>/$name . ++$num/e;
 $supp .= $_;
}
waitpid $pid, 0;

1 while unlink $sf;
open my $out, '>', $sf or die "$!";
print $out $supp;
close $out;
