package Test::Valgrind;

use strict;
use warnings;

=head1 NAME

Test::Valgrind - Test Perl code through valgrind.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 SYNOPSIS

    # From the command-line
    perl -MTest::Valgrind leaky.pl

    # In a test file
    use Test::More;
    eval 'use Test::Valgrind';
    plan skip_all => 'Test::Valgrind is required to test your distribution with valgrind' if $@;
    ...

    # In all the test files of a directory
    prove --exec 'perl -Iblib/lib -Iblib/arch -MTest::Valgrind' t/*.t

=head1 DESCRIPTION

This module is a front-end to the C<Test::Valgrind::*> API that lets you run Perl code through the C<memcheck> tool of the C<valgrind> memory debugger, to test it for memory errors and leaks.
If they aren't available yet, it will first generate suppressions for the current C<perl> interpreter and store them in the portable flavour of F<~/.perl/Test-Valgrind/suppressions/$VERSION>.
The actual run will then take place, and tests will be passed or failed according to the result of the analysis.

Due to the nature of perl's memory allocator, this module can't track leaks of Perl objects.
This includes non-mortalized scalars and memory cycles. However, it can track leaks of chunks of memory allocated in XS extensions with C<Newx> and friends or C<malloc>.
As such, it's complementary to the other very good leak detectors listed in the L</SEE ALSO> section.

=head1 CONFIGURATION

You can pass parameters to C<import> as a list of key / value pairs, where valid keys are :

=over 4

=item *

C<< tool => $tool >>

The L<Test::Valgrind::Tool> object (or class name) to use.

Defaults to L<Test::Valgrind::Tool::memcheck>.

=item *

C<< action => $action >>

The L<Test::Valgrind::Action> object (or class name) to use.

Defaults to L<Test::Valgrind::Action::Test>.

=item *

C<< diag => $bool >>

If true, print the output of the test script as diagnostics.

=item *

C<< callers => $number >>

Specify the maximum stack depth studied when valgrind encounters an error.
Raising this number improves granularity.

Default is 12.

=item *

C<< extra_supps => \@files >>

Also use suppressions from C<@files> besides C<perl>'s.

=item *

C<< no_def_supp => $bool >>

If true, do not use the default suppression file.

=back

=cut

# We use as little modules as possible in run mode so that they don't pollute
# the analysis. Hence all the requires.

my $run;

sub import {
 shift;

 if (@_ % 2) {
  require Carp;
  Carp::croak('Optional arguments must be passed as key => value pairs');
 }
 my %args = @_;

 if (defined $args{run} or $run) {
  require Perl::Destruct::Level;
  Perl::Destruct::Level::set_destruct_level(3);
  {
   my $oldfh = select STDOUT;
   $|++;
   select $oldfh;
  }
  $run = 1;
  return;
 }

 my ($file, $pm, $next);
 my $l = 0;
 while ($l < 1000) {
  $next = (caller $l++)[1];
  last unless defined $next;
  next if $next eq '-e' or $next =~ /^\s*\(\s*eval\s*\d*\s*\)\s*$/ or !-f $next;
  if ($next =~ /\.pm$/) {
   $pm   = $next;
  } else {
   $file = $next;
  }
 }
 unless (defined($file) or defined($file = $pm)) {
  require Test::Builder;
  Test::Builder->new->diag('Couldn\'t find a valid source file');
  return;
 }

 my $taint_mode;
 {
  open my $fh, '<', $file or last;
  my $first = <$fh>;
  close $fh;
  if ($first and my ($args) = $first =~ /^\s*#\s*!\s*perl\s*(.*)/) {
   $taint_mode = 1 if $args =~ /(?:^|\s)-T(?:$|\s)/;
  }
 }

 require Test::Valgrind::Command;
 my $cmd = Test::Valgrind::Command->new(
  command => 'Perl',
  args    => [ '-MTest::Valgrind=run,1', (('-T') x!! $taint_mode), $file ],
 );

 my $instanceof = sub {
  require Scalar::Util;
  Scalar::Util::blessed($_[0]) && $_[0]->isa($_[1]);
 };

 my $tool = delete $args{tool};
 unless ($tool->$instanceof('Test::Valgrind::Tool')) {
  require Test::Valgrind::Tool;
  $tool = Test::Valgrind::Tool->new(
   tool     => $tool || 'memcheck',
   callers  => delete($args{callers}),
  );
 }

 my $action = delete $args{action};
 unless ($action->$instanceof('Test::Valgrind::Action')) {
  require Test::Valgrind::Action;
  $action = Test::Valgrind::Action->new(
   action => $action || 'Test',
   diag   => delete($args{diag}),
  );
 }

 require Test::Valgrind::Session;
 my $sess = eval {
  Test::Valgrind::Session->new(
   min_version => $tool->requires_version,
   map { $_ => delete $args{$_} } qw/extra_supps no_def_supp/
  );
 };
 unless ($sess) {
  $action->abort($sess, $@);
  exit $action->status($sess);
 }

 eval {
  $sess->run(
   command => $cmd,
   tool    => $tool,
   action  => $action,
  );
 };
 if ($@) {
  require Test::Valgrind::Report;
  $action->report($sess, Test::Valgrind::Report->new_diag($@));
 }

 my $status = $sess->status;
 $status = 255 unless defined $status;

 exit $status;
}

END {
 if ($run and eval { require DynaLoader; 1 }) {
  my @rest;
  DynaLoader::dl_unload_file($_) or push @rest, $_ for @DynaLoader::dl_librefs;
  @DynaLoader::dl_librefs = @rest;
 }
}

=head1 CAVEATS

You can't use this module to test code given by the C<-e> command-line switch.

Perl 5.8 is notorious for leaking like there's no tomorrow, so the suppressions are very likely not to be very accurate on it. Anyhow, results will most likely be better if your perl is built with debugging enabled. Using the latest C<valgrind> available will also help.

This module is not really secure. It's definitely not taint safe. That shouldn't be a problem for test files.

What your tests output to C<STDOUT> and C<STDERR> is eaten unless you pass the C<diag> option, in which case it will be reprinted as diagnostics.

=head1 DEPENDENCIES

Valgrind 3.1.0 (L<http://valgrind.org>).

L<XML::Twig>, L<version>, L<File::HomeDir>, L<Env::Sanctify>, L<Perl::Destruct::Level>.

=head1 SEE ALSO

All the C<Test::Valgrind::*> API, including L<Test::Valgrind::Command>, L<Test::Valgrind::Tool>, L<Test::Valgrind::Action> and L<Test::Valgrind::Session>.

L<Test::LeakTrace>.

L<Devel::Leak>, L<Devel::LeakTrace>, L<Devel::LeakTrace::Fast>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind

=head1 ACKNOWLEDGEMENTS

Rafaël Garcia-Suarez, for writing and instructing me about the existence of L<Perl::Destruct::Level> (Elizabeth Mattijsen is a close second).

H.Merijn Brand, for daring to test this thing.

All you people that showed interest in this module, which motivated me into completely rewriting it.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind
