use 5.006;

use strict;
use warnings;
use ExtUtils::MakeMaker;

BEGIN {
 eval { require Config };
 die 'OS unsupported' if $@;
 Config->import(qw<%Config>);
 eval { require File::Spec };
 die 'OS unsupported' if $@;
}

# Inspired from Module::Install::Can
print "Checking for a valid C compiler in the PATH... ";
my @ccs = ($Config{cc});
unshift @ccs, $ENV{CC} if $ENV{CC};
my @path = File::Spec->path;
@ccs = map {
 my $cc = $_;
 File::Spec->file_name_is_absolute($cc)
   ? $cc
   : map File::Spec->catfile($_, $cc), @path
} @ccs;
my $has_cc;
CC:
for my $cc (@ccs) {
 if (-x $cc or MM->maybe_command($cc)) {
  $has_cc = $cc;
  last CC;
 }
}
my (@C);
if ($has_cc) {
 my $xs = 'Valgrind.xs';
 (my $c = $xs) =~ s/\.xs$/.c/;
 push @C, $c;
 print $has_cc, "\n";
} else {
 print "none\n";
}

my $dist = 'Test-Valgrind';

(my $name = $dist) =~ s{-}{::}g;

(my $file = $dist) =~ s{-}{/}g;
$file = "lib/$file.pm";

my %PREREQ_PM = (
 'Carp'                  => 0,
 'Digest::MD5'           => 0,
 'Env::Sanctify'         => 0,
 'File::HomeDir'         => '0.86',
 'File::Path'            => 0,
 'File::Spec'            => 0,
 'File::Temp'            => '0.14', # OO interface
 'Filter::Util::Call'    => 0,
 'Fcntl'                 => 0,
 'List::Util'            => 0,
 'POSIX'                 => 0,
 'Perl::Destruct::Level' => 0,
 'Scalar::Util'          => 0,
 'Test::Builder'         => 0,
 'Test::More'            => 0,
 'XML::Twig'             => 0,
 'base'                  => 0,
 'version'               => 0,
);

my %META = (
 configure_requires => {
  'File::Spec'          => 0,
  'ExtUtils::MakeMaker' => 0,
 },
 build_requires => {
  'ExtUtils::MakeMaker' => 0,
  'Test::More'          => 0,
  %PREREQ_PM,
 },
 recommends => {
  'DynaLoader' => 0,
  'XSLoader'   => 0,
 },
 dynamic_config => 1,
 resources => {
  bugtracker => "http://rt.cpan.org/Dist/Display.html?Name=$dist",
  homepage   => "http://search.cpan.org/dist/$dist/",
  license    => 'http://dev.perl.org/licenses/',
  repository => "http://git.profvince.com/?p=perl%2Fmodules%2F$dist.git",
 },
);

WriteMakefile(
 NAME             => $name,
 AUTHOR           => 'Vincent Pit <perl@profvince.com>',
 LICENSE          => 'perl',
 VERSION_FROM     => $file,
 ABSTRACT_FROM    => $file,
 OPTIMIZE         => '-g',
 C                => \@C,
 PREREQ_PM        => \%PREREQ_PM,
 MIN_PERL_VERSION => '5.006',
 META_MERGE       => \%META,
 dist             => {
  PREOP    => "pod2text -u $file > \$(DISTVNAME)/README",
  COMPRESS => 'gzip -9f', SUFFIX => 'gz',
 },
 clean            => {
  FILES => "$dist-* *.gcov *.gcda *.gcno cover_db Debian_CPANTS.txt"
 },
);
