package Test::Valgrind;

use strict;
use warnings;

use Carp qw/croak/;
use POSIX qw/SIGTERM/;
use Fcntl qw/F_SETFD/;
use Test::Builder;

use Perl::Destruct::Level level => 3;

use Test::Valgrind::Suppressions;

=head1 NAME

Test::Valgrind - Test Perl code through valgrind.

=head1 VERSION

Version 0.08

=cut

our $VERSION = '0.08';

=head1 SYNOPSIS

    use Test::More;
    eval 'use Test::Valgrind';
    plan skip_all => 'Test::Valgrind is required to test your distribution with valgrind' if $@;

    # Code to inspect for memory leaks/errors.

=head1 DESCRIPTION

This module lets you run some code through the B<valgrind> memory debugger, to test it for memory errors and leaks. Just add C<use Test::Valgrind> at the beginning of the code you want to test. Behind the hood, C<Test::Valgrind::import> forks so that the child can basically C<exec 'valgrind', $^X, $0> (except that of course C<$0> isn't right there). The parent then parses the report output by valgrind and pass or fail tests accordingly.

You can also use it from the command-line to test a given script :

    perl -MTest::Valgrind leaky.pl

Due to the nature of perl's memory allocator, this module can't track leaks of Perl objects. This includes non-mortalized scalars and memory cycles. However, it can track leaks of chunks of memory allocated in XS extensions with C<Newx> and friends or C<malloc>. As such, it's complementary to the other very good leak detectors listed in the L</SEE ALSO> section.

=head1 CONFIGURATION

You can pass parameters to C<import> as a list of key / value pairs, where valid keys are :

=over 4

=item *

C<< supp => $file >>

Also use suppressions from C<$file> besides perl's.

=item *

C<< no_supp => $bool >>

If true, do not use any suppressions.

=item *

C<< callers => $number >>

Specify the maximum stack depth studied when valgrind encounters an error. Raising this number improves granularity. Default is 12.

=item *

C<< extra => [ @args ] >>

Add C<@args> to valgrind parameters.

=item *

C<< diag => $bool >>

If true, print the raw output of valgrind as diagnostics (may be quite verbose).

=item *

C<< no_test => $bool >>

If true, do not actually output the plan and the tests results.

=item *

C<< cb => sub { my ($val, $name) = @_; ...; return $passed } >>

Specifies a subroutine to execute for each test instead of C<Test::More::is>. It receives the number of bytes leaked in C<$_[0]> and the test name in C<$_[1]>, and is expected to return true if the test passed and false otherwise. Defaults to

    sub {
     is($_[0], 0, $_[1]);
     (defined $_[0] and $_[0] == 0) : 1 : 0
    }

=back

=cut

my $Test = Test::Builder->new;

my $run;

sub _counter {
 (defined $_[0] and $_[0] == 0) ? 1 : 0;
}

sub _tester {
 $Test->is_num($_[0], 0, $_[1]);
 _counter(@_);
}

sub import {
 shift;
 croak 'Optional arguments must be passed as key => value pairs' if @_ % 2;
 my %args = @_;
 if (!defined $args{run} && !$run) {
  my ($file, $pm, $next);
  my $l = 0;
  while ($l < 1000) {
   $next = (caller $l++)[1];
   last unless defined $next;
   next unless $next ne '-e' and $next !~ /^\s*\(\s*eval\s*\d*\s*\)\s*$/
                             and -f $next;
   if ($next =~ /\.pm$/) {
    $pm = $next;
   } else {
    $file = $next;
   }
  }
  unless (defined $file) {
   $file = $pm;
   return unless defined $pm;
  }
  my $callers = $args{callers};
  $callers = 12 unless defined $callers;
  $callers = int $callers;
  my $vg = Test::Valgrind::Suppressions::VG_PATH;
  if (!$vg || !-x $vg) {
   require Config;
   for (split /$Config::Config{path_sep}/, $ENV{PATH}) {
    $_ .= '/valgrind';
    if (-x) {
     $vg = $_;
     last;
    }
   }
   if (!$vg) {
    $Test->skip_all('No valgrind executable could be found in your path');
    return;
   } 
  }
  pipe my $ordr, my $owtr or die "pipe(\$ordr, \$owtr): $!";
  pipe my $vrdr, my $vwtr or die "pipe(\$vrdr, \$vwtr): $!";
  my $pid = fork;
  if (!defined $pid) {
   die "fork(): $!";
  } elsif ($pid == 0) {
   setpgrp 0, 0 or die "setpgrp(0, 0): $!";
   close $ordr or die "close(\$ordr): $!";
   open STDOUT, '>&=', $owtr or die "open(STDOUT, '>&=', \$owtr): $!";
   close $vrdr or die "close(\$vrdr): $!";
   fcntl $vwtr, F_SETFD, 0 or die "fcntl(\$vwtr, F_SETFD, 0): $!";
   my @args = (
    $vg,
    '--tool=memcheck',
    '--leak-check=full',
    '--leak-resolution=high',
    '--num-callers=' . $callers,
    '--error-limit=yes',
    '--log-fd=' . fileno($vwtr)
   );
   unless ($args{no_supp}) {
    for (Test::Valgrind::Suppressions::supp_path(), $args{supp}) {
     push @args, '--suppressions=' . $_ if $_;
    }
   }
   if (defined $args{extra} and ref $args{extra} eq 'ARRAY') {
    push @args, @{$args{extra}};
   }
   push @args, $^X;
   push @args, '-I' . $_ for @INC;
   push @args, '-MTest::Valgrind=run,1', $file;
   print STDOUT "valgrind @args\n";
   local $ENV{PERL_DESTRUCT_LEVEL} = 3;
   local $ENV{PERL_DL_NONLAZY} = 1;
   exec { $args[0] } @args;
   die "exec @args: $!";
  }
  local $SIG{INT} = sub { kill -(SIGTERM) => $pid };
  $Test->plan(tests => 5) unless $args{no_test} or defined $Test->has_plan;
  my @tests = (
   'errors',
   'definitely lost', 'indirectly lost', 'possibly lost', 'still reachable'
  );
  my %res = map { $_ => 0 } @tests;
  close $owtr or die "close(\$owtr): $!";
  close $vwtr or die "close(\$vwtr): $!";
  while (<$vrdr>) {
   $Test->diag($_) if $args{diag};
   if (/^=+\d+=+\s*FATAL\s*:\s*(.*)/) {
    chomp(my $err = $1);
    $Test->diag("Valgrind error: $err");
    $res{$_} = undef for @tests;
   }
   if (/ERROR\s+SUMMARY\s*:\s+(\d+)/) {
    $res{errors} = int $1;
   } elsif (/([a-z][a-z\s]*[a-z])\s*:\s*([\d.,]+)/) {
    my ($cat, $count) = ($1, $2);
    if (exists $res{$cat}) {
     $cat =~ s/\s+/ /g;
     $count =~ s/[.,]//g;
     $res{$cat} = int $count;
    }
   }
  }
  waitpid $pid, 0;
  $Test->diag(do { local $/; <$ordr> }) if $args{diag};
  close $ordr or die "close(\$ordr): $!";
  my $failed = 5;
  my $cb = ($args{no_test} ? \&_counter
                           : ($args{cb} ? $args{cb} : \&_tester));
  for (@tests) {
   $failed -= $cb->($res{$_}, 'valgrind ' . $_) ? 1 : 0;
  }
  exit $failed;
 } else {
  $run = 1;
 }
}

END {
 if ($run and eval { require DynaLoader; 1 }) {
  my @rest;
  DynaLoader::dl_unload_file($_) and push @rest, $_ for @DynaLoader::dl_librefs;
  @DynaLoader::dl_librefs = @rest;
 }
}

=head1 CAVEATS

You can't use this module to test code given by the C<-e> command-line switch.

Perl 5.8 is notorious for leaking like there's no tomorrow, so the suppressions are very likely not to be very accurate on it. Anyhow, results will most likely be better if your perl is built with debugging enabled. Using the latest valgrind available will also help.

This module is not really secure. It's definitely not taint safe. That shouldn't be a problem for test files.

What your tests output to STDOUT is eaten unless you pass the C<diag> option, in which case it will be reprinted as diagnostics. STDERR is kept untouched.

=head1 DEPENDENCIES

Valgrind 3.1.0 (L<http://valgrind.org>).

L<Carp>, L<Fcntl>, L<POSIX> (core modules since perl 5) and L<Test::Builder> (since 5.6.2).

L<Perl::Destruct::Level>.

=head1 SEE ALSO

L<Devel::Leak>, L<Devel::LeakTrace>, L<Devel::LeakTrace::Fast>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind

=head1 ACKNOWLEDGEMENTS

Rafaël Garcia-Suarez, for writing and instructing me about the existence of L<Perl::Destruct::Level> (Elizabeth Mattijsen is a close second).

H.Merijn Brand, for daring to test this thing.

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind
