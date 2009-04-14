package Test::Valgrind;

use strict;
use warnings;

=head1 NAME

Test::Valgrind - Test Perl code through valgrind.

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 SYNOPSIS

    # From the command-line
    perl -MTest::Valgrind leaky.pl

    # From the command-line, snippet style
    perl -MTest::Valgrind -e 'leaky()'

    # In a test file
    use Test::More;
    eval 'use Test::Valgrind';
    plan skip_all => 'Test::Valgrind is required to test your distribution with valgrind' if $@;
    leaky();

    # In all the test files of a directory
    prove --exec 'perl -Iblib/lib -Iblib/arch -MTest::Valgrind' t/*.t

=head1 DESCRIPTION

This module is a front-end to the C<Test::Valgrind::*> API that lets you run Perl code through the C<memcheck> tool of the C<valgrind> memory debugger, to test it for memory errors and leaks.
If they aren't available yet, it will first generate suppressions for the current C<perl> interpreter and store them in the portable flavour of F<~/.perl/Test-Valgrind/suppressions/$VERSION>.
The actual run will then take place, and tests will be passed or failed according to the result of the analysis.

Due to the nature of perl's memory allocator, this module can't track leaks of Perl objects.
This includes non-mortalized scalars and memory cycles. However, it can track leaks of chunks of memory allocated in XS extensions with C<Newx> and friends or C<malloc>.
As such, it's complementary to the other very good leak detectors listed in the L</SEE ALSO> section.

=head1 METHODS

=head2 C<analyse [ %options ]>

Run a C<valgrind> analysis configured by C<%options> :

=over 4

=item *

C<< command => $command >>

The L<Test::Valgrind::Command> object (or class name) to use.

Defaults to L<Test::Valgrind::Command::PerlScript>.

=item *

C<< tool => $tool >>

The L<Test::Valgrind::Tool> object (or class name) to use.

Defaults to L<Test::Valgrind::Tool::memcheck>.

=item *

C<< action => $action >>

The L<Test::Valgrind::Action> object (or class name) to use.

Defaults to L<Test::Valgrind::Action::Test>.

=item *

C<< file => $file >>

The file name of the script to analyse.

Ignored if you supply your own custom C<command>, but mandatory otherwise.

=item *

C<< callers => $number >>

Specify the maximum stack depth studied when valgrind encounters an error.
Raising this number improves granularity.

Ignored if you supply your own custom C<tool>, otherwise defaults to C<12>.

=item *

C<< diag => $bool >>

If true, print the output of the test script as diagnostics.

Ignored if you supply your own custom C<action>, otherwise defaults to false.

=item *

C<< extra_supps => \@files >>

Also use suppressions from C<@files> besides C<perl>'s.

Defaults to empty.

=item *

C<< no_def_supp => $bool >>

If true, do not use the default suppression file.

Defaults to false.

=back

=cut

sub analyse {
 shift;

 my %args = @_;

 my $instanceof = sub {
  require Scalar::Util;
  Scalar::Util::blessed($_[0]) && $_[0]->isa($_[1]);
 };

 my $cmd = delete $args{command};
 unless ($cmd->$instanceof('Test::Valgrind::Command')) {
  require Test::Valgrind::Command;
  $cmd = Test::Valgrind::Command->new(
   command => $cmd || 'PerlScript',
   file    => delete $args{file},
   args    => [ '-MTest::Valgrind=run,1' ],
  );
 }

 my $tool = delete $args{tool};
 unless ($tool->$instanceof('Test::Valgrind::Tool')) {
  require Test::Valgrind::Tool;
  $tool = Test::Valgrind::Tool->new(
   tool     => $tool || 'memcheck',
   callers  => delete $args{callers},
  );
 }

 my $action = delete $args{action};
 unless ($action->$instanceof('Test::Valgrind::Action')) {
  require Test::Valgrind::Action;
  $action = Test::Valgrind::Action->new(
   action => $action || 'Test',
   diag   => delete $args{diag},
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
  return $action->status($sess);
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

 return $status;
}

=head2 C<import [ %options ]>

In the parent process, L</import> calls L</analyse> with the arguments it received itself - except that if no C<file> option was supplied, it tries to pick the highest caller context that looks like a script.
When the analyse finishes, it exists with the status that was returned.

In the child process, it just C<return>s so that the calling code is actually run under C<valgrind>.

=cut

# We use as little modules as possible in run mode so that they don't pollute
# the analysis. Hence all the requires.

my $run;

sub import {
 my $class = shift;
 $class = ref($class) || $class;

 if (@_ % 2) {
  require Carp;
  Carp::croak('Optional arguments must be passed as key => value pairs');
 }
 my %args = @_;

 if (defined delete $args{run} or $run) {
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

 my $file = delete $args{file};
 unless (defined $file) {
  my ($next, $last_pm);
  for (my $l = 0; 1; ++$l) {
   $next = (caller $l)[1];
   last unless defined $next;
   next if $next =~ /^\s*\(\s*eval\s*\d*\s*\)\s*$/;
   if ($next =~ /\.pmc?$/) {
    $last_pm = $next;
   } else {
    $file = $next;
    last;
   }
  }
  $file = $last_pm unless defined $file;
 }

 unless (defined $file) {
  require Test::Builder;
  Test::Builder->new->diag('Couldn\'t find a valid source file');
  return;
 }

 if ($file ne '-e') {
  exit $class->analyse(
   file => $file,
   %args,
  );
 }

 require File::Temp;
 my $tmp = File::Temp->new;

 require Filter::Util::Call;
 Filter::Util::Call::filter_add(sub {
  my $status = Filter::Util::Call::filter_read();
  if ($status > 0) {
   print $tmp $_;
  } elsif ($status == 0) {
   close $tmp;
   my $code = $class->analyse(
    file => $tmp->filename,
    %args,
   );
   exit $code;
  }
  $status;
 });
}

=head1 VARIABLES

=head2 C<$dl_unload>

When set to true, all dynamic extensions that were loaded during the analysis will be unloaded at C<END> time by L<DynaLoader::dl_unload_file>.

Since this obfuscates error stack traces, it's disabled by default.

=cut

our $dl_unload;

END {
 if ($dl_unload and $run and eval { require DynaLoader; 1 }) {
  my @rest;
  DynaLoader::dl_unload_file($_) or push @rest, $_ for @DynaLoader::dl_librefs;
  @DynaLoader::dl_librefs = @rest;
 }
}

=head1 CAVEATS

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
