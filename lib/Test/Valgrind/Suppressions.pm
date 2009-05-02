package Test::Valgrind::Suppressions;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Suppressions - Generate suppressions for given tool and command.

=head1 VERSION

Version 1.02

=cut

our $VERSION = '1.02';

=head1 DESCRIPTION

This module is an helper for generating suppressions.

=cut

use base qw/Test::Valgrind::Carp/;

=head1 METHODS

=head2 C<< generate tool => $tool, command => $command, target => $target >>

Generates suppressions for the command C<< $command->new_trainer >> and the tool C<< $tool->new_trainer >>, and writes them in the file specified by C<$target>.
The action used behind the scenes is L<Test::Valgrind::Action::Suppressions>.

Returns the status code.

=cut

sub generate {
 my $self = shift;

 my %args = @_;

 my $cmd = delete $args{command};
 unless (ref $cmd) {
  require Test::Valgrind::Command;
  $cmd = Test::Valgrind::Command->new(
   command => $cmd,
   args    => [ ],
  );
 }
 $cmd = $cmd->new_trainer;
 return unless defined $cmd;

 my $tool = delete $args{tool};
 unless (ref $tool) {
  require Test::Valgrind::Tool;
  $tool = Test::Valgrind::Tool->new(tool => $tool);
 }
 $tool = $tool->new_trainer;
 return unless defined $tool;

 my $target = delete $args{target};
 $self->_croak('Invalid target') unless $target and not ref $target;

 require Test::Valgrind::Action;
 my $action = Test::Valgrind::Action->new(
  action => 'Suppressions',
  target => $target,
  name   => 'PerlSuppression',
 );

 require Test::Valgrind::Session;
 my $sess = Test::Valgrind::Session->new(
  min_version => $tool->requires_version,
 );

 eval {
  $sess->run(
   command => $cmd,
   tool    => $tool,
   action  => $action,
  );
 };
 $self->_croak($@) if $@;

 my $status = $sess->status;
 $status = 255 unless defined $status;

 return $status;
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Command>, L<Test::Valgrind::Tool>, L<Test::Valgrind::Action::Suppressions>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind-suppressions at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Suppressions

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Suppressions
