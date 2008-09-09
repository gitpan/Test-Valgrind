use strict;
use warnings;

use Test::More;
eval {
 use Test::Valgrind
  diag    => 1,
  no_test => 1,
  no_supp => 1,
  callers => 50,
  extra   => [ qw/--show-reachable=yes --gen-suppressions=all/ ];
};
if ($@) {
 plan skip_all => 'Test::Valgrind is required to run test your distribution with valgrind';
} else {
 eval "
  use lib qw{blib/arch};
  require XSLoader;
  XSLoader::load('Test::Valgrind', \$Test::Valgrind::VERSION);
 ";
 unless ($@) {
  Test::Valgrind::notleak("valgrind it!");
 } else {
  diag $@;
 }
}

1;
