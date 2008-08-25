use strict;
use warnings;

use File::Copy qw/copy/;

my ($bak) = @ARGV;
exit 1 unless defined $bak;

my $mk = './Makefile';
exit 1 unless defined $mk and -e $mk and -r _ and -w _;

select STDERR;

print "Fixing Makefile install targets\n";

if (-e $bak && (stat $bak)[9] >= (stat $mk)[9]) { # mtime
 print "Makefile is old\n";
 copy($bak, $mk);
} else {
 print "Makefile is new\n";
 copy($mk, $bak);
}

open my $in,  '<', $bak or die "open(<$bak): $!";
open my $out, '>', $mk  or die "open(>$mk): $!";
while (<$in>) {
 s!^(\s*)\$\(INST_ARCHLIB\)\s+(\$\(DESTINSTALL(?:ARCHLIB|SITEARCH|VENDORARCH)\))\s*\\\s*!$1blib/archpub $2/\$(FULLEXT) \\\n!g;
 print $out $_;
}
close $out;
close $in;

utime time, time, $bak; # Update mtime
