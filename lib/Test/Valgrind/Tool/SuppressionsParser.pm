package Test::Valgrind::Tool::SuppressionsParser;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Tool::SuppressionsParser - Mock Test::Valgrind::Tool for parsing valgrind suppressions.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 DESCRIPTION

This class provides a default C<parse_suppressions> method, so that real tools for which suppressions are meaningful can exploit it by inheriting.

It's not meant to be used directly as a tool.

=cut

use base qw/Test::Valgrind::Carp/;

=head1 METHODS

=head2 C<new>

Just a croaking stub to remind you not to use this class as a real tool.

If your tool both inherit from this class and from C<Test::Valgrind::Tool>, and that you want to dispatch the call to your C<new> to its ancestors', be careful with C<SUPER> which may end up calling this dieing version of C<new>.
The solution is to either put C<Test::Valgrind::Tool> first in the C<@ISA> list or to explicitely call C<Test::Valgrind::Tool::new> instead of C<SUPER::new>.

=cut

sub new { shift->_croak('This mock tool isn\'t meant to be used directly') }

=head2 C<report_class_suppressions $session>

Generated reports are L<Test::Valgrind::Report::Suppressions> objects.
Their C<data> member contains the raw text of the suppression.

=cut

sub report_class_suppressions { 'Test::Valgrind::Report::Suppressions' }

=head2 C<parse_suppressions $session, $fh>

Parses the filehandle C<$fh> fed with the output of F<valgrind --gen-suppressions=all> and sends a report to the session C<$session> for each suppression.

=cut

sub parse_suppressions {
 my ($self, $sess, $fh) = @_;

 my ($s, $in) = ('', 0);
 my @supps;

 while (<$fh>) {
  s/^\s*#\s//;
  next if /^==/;
  next if /valgrind/; # and /\Q$file\E/;
  s/^\s*//;
  s/<[^>]+>//;
  s/\s*$//;
  next unless length;
  if ($_ eq '{') {
   $in = 1;
  } elsif ($_ eq '}') {
   my $unknown_tail;
   ++$unknown_tail while $s =~ s/(\n)\s*obj:\*\s*$/$1/;
   $s .= "...\n" if $unknown_tail and $sess->version ge '3.4.0';
   push @supps, $s;
   $s  = '';
   $in = 0;
  } elsif ($in) {
   $s .= "$_\n";
  }
 }

 my @extra;
 for (@supps) {
  if (/\bfun:(m|c|re)alloc\b/) {
   my $t = $1;
   my %call;
   if ($t eq 'm') { # malloc can also be called by calloc or realloc
    $call{$_} = 1 for qw/calloc realloc/;
   } elsif ($t eq 're') { # realloc can also call malloc or free
    $call{$_} = 0 for qw/malloc free/;
   } elsif ($t eq 'c') { # calloc can also call malloc
    $call{$_} = 0 for qw/malloc/;
   }
   my $c = $_;
   for (keys %call) {
    my $d = $c;
    $d =~ s/\b(fun:${t}alloc)\b/$call{$_} ? "$1\nfun:$_" : "fun:$_\n$1"/e;
    # Remove one line for each line added or valgrind will hate us
    $d =~ s/\n(.+?)\s*$/\n/;
    push @extra, $d;
   }
  }
 }

 my %dupes;
 @dupes{@supps, @extra} = ();
 @supps = keys %dupes;

 my $num;
 $sess->report($self->report_class($sess)->new(
  id   => ++$num,
  kind => 'Suppression',
  data => $_,
 )) for @supps;
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Tool>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Tool::SuppressionsParser

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

# End of Test::Valgrind::Tool::SuppressionsParser

package Test::Valgrind::Report::Suppressions;

use base qw/Test::Valgrind::Report/;

sub kinds { shift->SUPER::kinds(), 'Suppression' }

sub valid_kind {
 my ($self, $kind) = @_;

 $self->SUPER::valid_kind($kind) or $kind eq 'Suppression'
}

1; # End of Test::Valgrind::Report::Suppressions
