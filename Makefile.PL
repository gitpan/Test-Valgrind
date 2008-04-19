use strict;
use warnings;
use ExtUtils::MakeMaker;

my $has_vg = 0;
print 'Checking for valgrind >= 3.1.0 in PATH... ';
for (split /:/, $ENV{PATH}) {
 my $vg = $_ . '/valgrind';
 if (-x $vg) {
  my $ver = qx/$vg --version/;
  if ($ver =~ s/^valgrind-//) {
   $ver = join '', map chr, split /\./, $ver;
   if ($ver ge v3.1.0) {
    print "yes, $vg\n";
    $has_vg = 1;
    last;
   }
  }
 }
}
if (!$has_vg) {
 print "no\n";
 die 'OS unsupported';
}

my $BUILD_REQUIRES = {
 'ExtUtils::MakeMaker' => 0,
 'Test::More'          => 0
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

my $supp = 'Test/Valgrind/perlTestValgrind.supp';

WriteMakefile(
    NAME          => 'Test::Valgrind',
    AUTHOR        => 'Vincent Pit <perl@profvince.com>',
    LICENSE       => 'perl',
    VERSION_FROM  => 'lib/Test/Valgrind.pm',
    ABSTRACT_FROM => 'lib/Test/Valgrind.pm',
    PL_FILES      => { './Gensupp.PL' => 'lib/' . $supp },
    PM            => {
        'lib/Test/Valgrind.pm'
        => '$(INST_LIB)/Test/Valgrind.pm',
        'lib/Test/Valgrind/Suppressions.pm'
        => '$(INST_ARCHLIB)/Test/Valgrind/Suppressions.pm',
        'lib/' . $supp => '$(INST_ARCHLIB)/' . $supp,
    },
    PREREQ_PM     => {
        'Carp'       => 0,
        'Exporter'   => 0,
        'POSIX'      => 0,
        'Test::More' => 0,
    },
    dist          => {
        PREOP      => 'pod2text lib/Test/Valgrind.pm > $(DISTVNAME)/README; '
                      . build_req,
        COMPRESS   => 'gzip -9f', SUFFIX => 'gz',
    },
    clean         => { FILES => "Test-Valgrind-* lib/$supp *.gcov *.gcda *.gcno cover_db" },
);
1 while unlink 'lib/' . $supp;

