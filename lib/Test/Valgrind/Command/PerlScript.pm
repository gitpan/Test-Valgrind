package Test::Valgrind::Command::PerlScript;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Command::PerlScript - A Test::Valgrind command that invokes a perl script.

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 DESCRIPTION

This command is meant to abstract the argument list handling of a C<perl> script.

=cut

use base qw/Test::Valgrind::Command::Perl Test::Valgrind::Carp/;

=head1 METHODS

This class inherits L<Test::Valgrind::Command::Perl>.

=head2 C<< new file => $file, [ taint_mode => $taint_mode ], ... >>

Your usual constructor.

C<$file> is the path to the C<perl> script you want to run.

C<$taint_mode> is a boolean that specifies if the script should be run under taint mode.
If C<undef> is passed (which is the default), the constructor will try to infer it from the shebang line of the script.

Other arguments are passed straight to C<< Test::Valgrind::Command::Perl->new >>.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 my $file       = delete $args{file};
 $class->_croak('Invalid script file') unless $file and -e $file;
 my $taint_mode = delete $args{taint_mode};

 my $self = bless $class->SUPER::new(%args), $class;

 $self->{file} = $file;

 if (not defined $taint_mode and open my $fh, '<', $file) {
  my $first = <$fh>;
  close $fh;
  if ($first and my ($args) = $first =~ /^\s*#\s*!\s*perl\s*(.*)/) {
   $taint_mode = 1 if $args =~ /(?:^|\s)-T(?:$|\s)/;
  }
  $taint_mode = 0 unless defined $taint_mode;
 }
 $self->{taint_mode} = $taint_mode;

 return $self;
}

sub new_trainer { Test::Valgrind::Command::Perl->new_trainer }

=head2 C<file>

Read-only accessor for the C<file> option.

=head2 C<taint_mode>

Read-only accessor for the C<taint_mode> option.

=cut

eval "sub $_ { \$_[0]->{$_} }" for qw/file taint_mode/;

sub args {
 my $self = shift;

 return $self->SUPER::args(@_),
        (('-T') x!! $self->taint_mode),
        $self->file
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Command::Perl>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Command::PerlScript

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Command::PerlScript
