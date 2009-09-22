package Test::Valgrind::Tool;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Tool - Base class for Test::Valgrind tools.

=head1 VERSION

Version 1.10

=cut

our $VERSION = '1.10';

=head1 DESCRIPTION

This class is the base for L<Test::Valgrind> tools.

They wrap around C<valgrind> tools by parsing its output and sending reports to the parent session whenever an error occurs.
They are expected to function both in suppressions generation and in analysis mode.

=cut

use base qw/Test::Valgrind::Component Test::Valgrind::Carp/;

=head1 METHODS

=head2 C<requires_version>

The minimum C<valgrind> version needed to run this tool.
Defaults to C<3.1.0>.

=cut

sub requires_version { '3.1.0' }

=head2 C<< new tool => $tool >>

Creates a new tool object of type C<$tool> by requiring and redispatching the method call to the module named C<$tool> if it contains C<'::'> or to C<Test::Valgrind::Tool::$tool> otherwise.
The class represented by C<$tool> must inherit this class.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 if ($class eq __PACKAGE__) {
  my $tool = delete $args{tool} || 'memcheck';
  $tool =~ s/[^\w:]//g;
  $tool = __PACKAGE__ . "::$tool" if $tool !~ /::/;
  $class->_croak("Couldn't load tool $tool: $@") unless eval "require $tool; 1";
  return $tool->new(%args);
 }

 $class->SUPER::new(@_);
}

=head2 C<new_trainer>

Creates a new tool object suitable for generating suppressions.

Defaults to return C<undef>, which skips suppression generation.

=cut

sub new_trainer { }

=head2 C<parser_class $session>

Returns the class from which the parser for this tool output will be instanciated.

This method must be implemented when subclassing.

=cut

sub parser_class;

=head2 C<report_class $session>

Returns the class in which suppression reports generated by this tool will be blessed.

This method must be implemented when subclassing.

=cut

sub report_class;

=head2 C<args $session>

Returns the list of tool-specific arguments that are to be passed to C<valgrind>.
All the suppression arguments are already handled by the session.

Defaults to the empty list.

=cut

sub args { }

=head2 C<suppressions_tag $session>

Returns a identifier that will be used to pick up the right suppressions for running the tool, or C<undef> to indicate that no special suppressions are needed.

This method must be implemented when subclassing.

=cut

sub suppressions_tag;

=head2 C<start $session>

Called when the C<$session> starts.

Defaults to set L<Test::Valgrind::Component/started>.

=head2 C<filter $session, $report>

The <$session> calls this method after receiving a report from the parser and before letting the command filter it.
You can either return a mangled C<$report> (which does not need to be a clone of the original) or C<undef> if you want the action to ignore it completely.

Defaults to the identity function.

=cut

sub filter { $_[2] }

=head2 C<finish $session>

Called when the C<$session> finishes.

Defaults to clear L<Test::Valgrind::Component/started>.

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Component>, L<Test::Valgrind::Session>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Tool

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Tool
