package Test::Valgrind::Test::Action;

use strict;
use warnings;

use base qw/Test::Valgrind::Action::Test/;

my $extra_tests;

BEGIN {
 eval {
  require Test::Valgrind;
  require XSLoader;
  XSLoader::load('Test::Valgrind', $Test::Valgrind::VERSION);
 };
 if ($@) {
  $extra_tests = 0;
 } else {
  $extra_tests = 2;
  *report = *report_smart;
 }
}

use Test::Builder;

sub new { shift->SUPER::new(extra_tests => $extra_tests) }

sub report_smart {
 my ($self, $sess, $report) = @_;

 if ($report->can('is_leak') and $report->is_leak) {
  my $data  = $report->data;
  my $trace = join ' ', map { $_->[2] } @{$data->{stack} || []}[0 .. 2];
  if ($trace eq 'malloc XS_Test__Valgrind_leak Perl_pp_entersub') {
   my $tb = Test::Builder->new;
   $tb->diag("The subsequent report was correctly caught:\n" . $report->dump);
   $tb->is_eq($data->{leakedbytes},  10_000, '10_000 bytes leaked');
   $tb->is_eq($data->{leakedblocks}, 1,      '  in one block');
   return;
  }
 }

 $self->SUPER::report($sess, $report);
}

1;
