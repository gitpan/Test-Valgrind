use 5.006;

use strict;
use warnings;
use ExtUtils::MakeMaker;

BEGIN {
 eval { require Config };
 die 'OS unsupported' if $@;
 Config->import(qw/%Config/);
 eval { require File::Spec };
 die 'OS unsupported' if $@;
}

my $vg;
print 'Checking for valgrind >= 3.1.0 in PATH... ';
for (split /:/, $ENV{PATH}) {
 $_ .= '/valgrind';
 if (-x) {
  my $ver = qx/$_ --version/;
  if ($ver =~ s/^valgrind-//) {
   $ver = join '', map chr, split /\./, $ver;
   if ($ver ge v3.1.0) {
    print "$_\n";
    $vg = $_;
    last;
   }
  }
 }
}
if (!$vg) {
 print "no\n";
 die 'OS unsupported';
}

# Inspired from Module::Install::Can
print "Checking for a valid C compiler in the PATH... ";
my @ccs = ($Config{cc});
unshift @ccs, $ENV{CC} if $ENV{CC};
my $cc;
CC:
for my $c (@ccs) {
 for my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
  my $abs = File::Spec->catfile($dir, $c);
  if (-x $abs or MM->maybe_command($abs)) {
   $cc = $c;
   last CC;
  }
 }
}
my (@C);
if ($cc) {
 my $xs = 'Valgrind.xs';
 (my $c = $xs) =~ s/\.xs$/.c/;
 push @C, $c;
 print $cc, "\n";
} else {
 print "none\n";
}

my $BUILD_REQUIRES = {
 'ExtUtils::MakeMaker' => 0,
 'File::Copy'          => 0,
 'Test::More'          => 0,
 'XSLoader'            => 0
};

sub build_req {
 my $tometa = ' >> $(DISTVNAME)/META.yml;';
 my $build_req = 'echo "build_requires:" ' . $tometa;
 foreach my $mod ( sort { lc $a cmp lc $b } keys %$BUILD_REQUIRES ) {
  my $ver = $BUILD_REQUIRES->{$mod};
  $build_req .= sprintf 'echo "    %-30s %s" %s', "$mod:", $ver, $tometa;
 }
 return $build_req;
}

my $supp = 'lib/Test/Valgrind/Suppressions';
open my $tpl, '<', $supp . '.tpl' or die "open($supp.tpl): $!";
open my $out, '>', $supp . '.pm'  or die "open($supp.pm): $!";
while (<$tpl>) {
 s/(VG_PATH\s*=>\s*)undef/$1'$vg'/g;
 print $out $_;
}
close $out;
close $tpl;

$supp = 'Test/Valgrind/perlTestValgrind.supp';

WriteMakefile(
    NAME          => 'Test::Valgrind',
    AUTHOR        => 'Vincent Pit <perl@profvince.com>',
    LICENSE       => 'perl',
    VERSION_FROM  => 'lib/Test/Valgrind.pm',
    ABSTRACT_FROM => 'lib/Test/Valgrind.pm',
    PL_FILES      => {
        './Gensupp.PL'    => 'blib/archpub/' . $supp,
        './FixInstall.PL' => 'Makefile.bak',
    },
    OPTIMIZE      => '-g',
    PM            => {
        'lib/Test/Valgrind.pm'
        => '$(INST_LIB)/Test/Valgrind.pm',
        'lib/Test/Valgrind/Suppressions.pm'
        => 'blib/archpub/Test/Valgrind/Suppressions.pm',
    },
    C             => \@C,
    PREREQ_PM     => {
        'Carp'                  => 0,
        'Exporter'              => 0,
        'Fcntl'                 => 0,
        'POSIX'                 => 0,
        'Perl::Destruct::Level' => 0,
        'Test::Builder'         => 0,
    },
    dist          => {
        PREOP      => "touch lib/$supp; "
                      . 'pod2text lib/Test/Valgrind.pm > $(DISTVNAME)/README; '
                      . build_req,
        COMPRESS   => 'gzip -9f', SUFFIX => 'gz',
    },
    clean         => { FILES => "Test-Valgrind-* lib/$supp Makefile.bak *.gcov *.gcda *.gcno cover_db Debian_CPANTS.txt" },
);
1 while unlink 'lib/' . $supp;

package MY;

sub test {
 my $test = shift->SUPER::test(@_);
 return "test :: Makefile.bak blib/archpub/Test/Valgrind/perlTestValgrind.supp\n" . $test;
}

sub postamble {
 <<'POSTAMBLE';
clean ::
	$(CP) lib/Test/Valgrind/Suppressions.{tpl,pm}
	$(TOUCH) lib/Test/Valgrind/perlTestValgrind.supp
POSTAMBLE
}
