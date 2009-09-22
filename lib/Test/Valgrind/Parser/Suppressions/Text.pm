package Test::Valgrind::Parser::Suppressions::Text;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Parser::Suppressions::Text - Parse valgrind suppressions output as text blocks.

=head1 VERSION

Version 1.10

=cut

our $VERSION = '1.10';

=head1 DESCRIPTION

This is a L<Test::Valgrind::Parser> object that can extract suppressions from C<valgrind>'s text output.

=cut

use base qw/Test::Valgrind::Parser::Text Test::Valgrind::Carp/;

=head1 METHODS

=head2 C<report_class>

Generated reports are C<Test::Valgrind::Report::Suppressions> objects.
Their C<data> member contains the raw text of the suppression.

=cut

sub report_class { 'Test::Valgrind::Report::Suppressions' }

=head2 C<parse $session, $fh>

Parses the filehandle C<$fh> fed with the output of F<valgrind --gen-suppressions=all> and sends a report to the session C<$session> for each suppression.

=cut

sub parse {
 my ($self, $sess, $fh) = @_;

 my ($s, $in) = ('', 0);
 my @supps;

 while (<$fh>) {
  s/^\s*#\s//;        # Strip comments

  next if /^==/;      # Valgrind info line
  next if /valgrind/; # and /\Q$file\E/;

  s/^\s*//;           # Strip leading spaces
  s/<[^>]+>//;        # Strip tags
  s/\s*$//;           # Strip trailing spaces
  next unless length;

  if ($_ eq '{') {      # A suppression block begins
   $in = 1;
  } elsif ($_ eq '}') { # A suppression block ends
   # With valgrind 3.4.0, we can replace unknown series of frames by '...'
   if ($sess->version ge '3.4.0') {
    my $unknown_tail;
    ++$unknown_tail while $s =~ s/(\n)\s*obj:\*\s*$/$1/;
    $s .= "...\n" if $unknown_tail;
   }

   push @supps, $s;     # Add the suppression that just ended to the list
   $s  = '';            # Reset the state
   $in = 0;
  } elsif ($in) {       # We're inside a suppresion block
   $s .= "$_\n";        # Append the current line to the state
  }
 }

 my @extra;

 for (@supps) {
  if (/\bfun:(m|c|re)alloc\b/) {
   my $t = $1;

   my %call; # Frames to append (if the value is 1) or to prepend (if it's 0)
   if ($t eq 'm') {       # malloc can also be called by calloc or realloc
    $call{$_} = 1 for qw/calloc realloc/;
   } elsif ($t eq 're') { # realloc can also call malloc or free
    $call{$_} = 0 for qw/malloc free/;
   } elsif ($t eq 'c') {  # calloc can also call malloc
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

 my $num;
 $sess->report($self->report_class($sess)->new(
  id   => ++$num,
  kind => 'Suppression',
  data => $_,
 )) for @supps, @extra;
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Parser::Text>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Parser::Suppressions::Text

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

# End of Test::Valgrind::Parser::Suppressions::Text

package Test::Valgrind::Report::Suppressions;

use base qw/Test::Valgrind::Report/;

sub kinds { shift->SUPER::kinds(), 'Suppression' }

sub valid_kind {
 my ($self, $kind) = @_;

 $self->SUPER::valid_kind($kind) or $kind eq 'Suppression'
}

1; # End of Test::Valgrind::Report::Suppressions
