#!perl -T

use strict;
use warnings;

use Test::More;

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage" if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage" if $@;

my $trustparents = { coverage_class => 'Pod::Coverage::CountParents' };

plan tests => 14;

pod_coverage_ok('Test::Valgrind');

pod_coverage_ok('Test::Valgrind::Action');
pod_coverage_ok('Test::Valgrind::Action::Captor');
pod_coverage_ok('Test::Valgrind::Action::Suppressions', $trustparents);
pod_coverage_ok('Test::Valgrind::Action::Test', $trustparents);

pod_coverage_ok('Test::Valgrind::Carp');

pod_coverage_ok('Test::Valgrind::Command');
pod_coverage_ok('Test::Valgrind::Command::Perl', $trustparents);

pod_coverage_ok('Test::Valgrind::Report');
pod_coverage_ok('Test::Valgrind::Session');
pod_coverage_ok('Test::Valgrind::Suppressions');

pod_coverage_ok('Test::Valgrind::Tool');
pod_coverage_ok('Test::Valgrind::Tool::SuppressionsParser');
pod_coverage_ok('Test::Valgrind::Tool::memcheck', $trustparents);
