package Test::Valgrind::Test::Action;

use strict;
use warnings;

use base qw<Test::Valgrind::Action::Test>;

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
  my @trace = map $_->[2] || '?',
               @{$data->{stack} || []}[0 .. 3];
  my $valid_trace = (
       $trace[0] eq 'malloc'
   and $trace[1] eq 'tv_leak'
   and ($trace[2] eq 'Perl_pp_entersub' or $trace[3] eq 'Perl_pp_entersub')
  );

  if ($valid_trace) {
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
