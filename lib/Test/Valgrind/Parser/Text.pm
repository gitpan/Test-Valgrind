package Test::Valgrind::Parser::Text;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Parser::Text - Parse valgrind output as a text stream.

=head1 VERSION

Version 1.10

=cut

our $VERSION = '1.10';

=head1 DESCRIPTION

This is a L<Test::Valgrind::Parser> object that can extract suppressions from C<valgrind>'s text output.

=cut

use base qw/Test::Valgrind::Parser/;

=head1 METHODS

=head2 C<args $session, $fh>

Returns the arguments needed to tell C<valgrind> to print to the filehandle C<$fh>.

=cut

sub args {
 my $self = shift;
 my ($session, $fh) = @_;

 return (
  $self->SUPER::args(@_),
  '--log-fd=' . fileno($fh),
 );
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Parser>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Parser::Text

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Parser::Text
