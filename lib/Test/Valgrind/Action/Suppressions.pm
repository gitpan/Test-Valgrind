package Test::Valgrind::Action::Suppressions;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Action::Suppressions - Generate suppressions for a given tool.

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 DESCRIPTION

This action just writes the contents of the suppressions reports received into the suppression file.

=cut

use base qw/Test::Valgrind::Action Test::Valgrind::Action::Captor/;

=head1 METHODS

This class inherits L<Test::Valgrind::Action>.

=head2 C<< new name => $name, target => $target, ... >>

Your usual constructor.

You need to specify the suppression prefix as the value of C<name>, and the target file as C<target>.

Other arguments are passed straight to C<< Test::Valgrind::Action->new >>.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 my %validated;

 for (qw/name target/) {
  my $arg = delete $args{$_};
  $class->_croak("'$_' is expected to be a plain scalar")
                                                   unless $arg and not ref $arg;
  $validated{$_} = $arg;
 }

 my $self = $class->SUPER::new(%args);

 $self->{$_} = $validated{$_} for qw/name target/;

 $self;
}

sub do_suppressions { 1 }

=head2 C<name>

Read-only accessor for the C<name> option.

=cut

sub name   { $_[0]->{name} }

=head2 C<target>

Read-only accessor for the C<target> option.

=cut

sub target { $_[0]->{target} }

sub start {
 my ($self, $sess) = @_;

 $self->SUPER::start($sess);

 $self->{status} = undef;
 $self->{total}  = 0;
 delete $self->{diagnostics};

 if ($self->{fh}) {
  close $self->{fh} or $self->_croak("close(\$self->{fh}): $!");
 }

 my $target = $self->target;

 require File::Spec;
 my ($vol, $dir, $file) = File::Spec->splitpath($target);
 my $base = File::Spec->catpath($vol, $dir, '');
 unless (-e $base) {
  require File::Path;
  File::Path::mkpath([ $base ]);
 } else {
  1 while unlink $target;
 }

 open $self->{fh}, '>', $target
                or $self->_croak("open(\$self->{fh}, '>', \$self->target): $!");

 $self->save_fh(\*STDOUT => '>' => undef);
 $self->save_fh(\*STDERR => '>' => undef);

 return;
}

sub abort {
 my $self = shift;

 $self->restore_all_fh;

 print $self->{diagnostics} if defined $self->{diagnostics};
 delete $self->{diagnostics};

 $self->{status} = 255;

 $self->SUPER::abort(@_);
}

sub report {
 my ($self, $sess, $report) = @_;

 if ($report->is_diag) {
  my $data = $report->data;
  1 while chomp $data;
  $self->{diagnostics} .= "$data\n";
  return;
 }

 $self->SUPER::report($sess, $report);

 ++$self->{total};

 print { $self->{fh} } "{\n"
                       . $self->name . $report->id . "\n"
                       . $report->data
                       . "}\n";

 return;
}

sub finish {
 my ($self, $sess) = @_;

 $self->SUPER::finish($sess);

 $self->restore_all_fh;

 close $self->{fh} or $self->_croak("close(\$self->{fh}): $!");

 print $self->{diagnostics} if defined $self->{diagnostics};
 delete $self->{diagnostics};
 print "Found $self->{total} distinct suppressions\n";

 $self->{status} = 0;

 return;
}

sub status { $_[0]->{status} }

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Action>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Action::Suppressions

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Action::Supressions
