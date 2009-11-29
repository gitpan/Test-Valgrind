package Test::Valgrind::Action;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Action - Base class for Test::Valgrind actions.

=head1 VERSION

Version 1.12

=cut

our $VERSION = '1.12';

=head1 DESCRIPTION

This class is the base for L<Test::Valgrind> actions.

Actions are called each time a tool encounter an error and decide what to do with it (for example passing or failing tests).

=cut

use base qw/Test::Valgrind::Component Test::Valgrind::Carp/;

=head1 METHODS

=head2 C<< new action => $action >>

Creates a new action object of type C<$action> by requiring and redispatching the method call to the module named C<$action> if it contains C<'::'> or to C<Test::Valgrind::Action::$action> otherwise.
The class represented by C<$action> must inherit this class.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 if ($class eq __PACKAGE__) {
  my $action = delete $args{action} || 'Test';
  $action =~ s/[^\w:]//g;
  $action = __PACKAGE__ . "::$action" if $action !~ /::/;
  $class->_croak("Couldn't load action $action: $@")
                                               unless eval "require $action; 1";
  return $action->new(%args);
 }

 $class->SUPER::new(@_);
}

=head2 C<do_suppressions>

Indicates if the action wants C<valgrind> to run in suppression-generating mode or in analysis mode.

=cut

sub do_suppressions { 0 }

=head2 C<start $session>

Called when the C<$session> starts.

Defaults to set L<Test::Valgrind::Component/started>.

=head2 C<report $session, $report>

Invoked each time the C<valgrind> process attached to the C<$session> spots an error.
C<$report> is a L<Test::Valgrind::Report> object describing the error.

Defaults to check L<Test::Valgrind::Component/started>.

=cut

sub report {
 my ($self) = @_;

 $self->_croak('Action isn\'t started') unless $self->started;

 return;
}

=head2 C<abort $session, $msg>

Triggered when the C<$session> has to interrupt the action.

Defaults to croak.

=cut

sub abort { $_[0]->_croak($_[2]) }

=head2 C<finish $session>

Called when the C<$session> finishes.

Defaults to clear L<Test::Valgrind::Component/started>.

=head2 C<status $session>

Returns the status code corresponding to the last run of the action.

=cut

sub status {
 my ($self, $sess) = @_;

 my $started = $self->started;

 $self->_croak("Action was never started") unless defined $started;
 $self->_croak("Action is still running")  if $started;

 return;
}

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

    perldoc Test::Valgrind::Action

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Action
