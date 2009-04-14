package Test::Valgrind::Command::Perl;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Command::Perl - A Test::Valgrind command that invokes perl.

=head1 VERSION

Version 1.01

=cut

our $VERSION = '1.01';

=head1 DESCRIPTION

=cut

use Env::Sanctify ();

use base qw/Test::Valgrind::Command Test::Valgrind::Carp/;

=head1 METHODS

This class inherits L<Test::Valgrind::Command>.

=head2 C<< new perl => $^X, inc => \@INC, ... >>

Your usual constructor.

The C<perl> option specifies which C<perl> executable will run the arugment list given in C<args>.
It defaults to C<$^X>.

C<inc> is a reference to an array of paths that will be passed as C<-I> to the invoked command.
It defaults to C<@INC>.

Other arguments are passed straight to C<< Test::Valgrind::Command->new >>.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 my $perl = delete($args{perl}) || $^X;
 my $inc  = delete($args{inc})  || [ @INC ];
 $class->_croak('Invalid INC list') unless ref $inc eq 'ARRAY';

 my $trainer_file = delete $args{trainer_file};

 my $self = bless $class->SUPER::new(%args), $class;

 $self->{perl}         = $perl;
 $self->{inc}          = $inc;
 $self->{trainer_file} = $trainer_file;

 return $self;
}

sub new_trainer {
 my $self = shift;

 require File::Temp;
 my ($fh, $file) = File::Temp::tempfile(UNLINK => 0);
 {
  my $curpos = tell DATA;
  print $fh $_ while <DATA>;
  seek DATA, $curpos, 0;
 }
 close $fh or $self->_croak("close(tempscript): $!");

 $self->new(
  args         => [ '-MTest::Valgrind=run,1', $file ],
  trainer_file => $file,
  @_
 );
}

=head2 C<perl>

Read-only accessor for the C<perl> option.

=cut

sub perl { $_[0]->{perl} }

=head2 C<inc>

Read-only accessor for the C<inc> option.

=cut

sub inc { @{$_[0]->{inc} || []} }

sub args {
 my $self = shift;

 return $self->perl,
        map("-I$_", $self->inc),
        $self->SUPER::args(@_);
}

=head2 C<env $session>

Returns an L<Env::Sanctify> object that sets the environment variables C<PERL_DESTRUCT_LEVEL> to C<3> and C<PERL_DL_NONLAZY> to C<1> during the run.

=cut

sub env {
 Env::Sanctify->sanctify(
  env => {
   PERL_DESTRUCT_LEVEL => 2,
   PERL_DL_NONLAZY     => 1,
  },
 );
}

sub suppressions_tag {
 my ($self) = @_;

 unless (defined $self->{suppressions_tag}) {
  my $env = Env::Sanctify->sanctify(sanctify => [ qr/^PERL/ ]);

  open my $pipe, '-|', $self->perl, '-V'
                     or $self->_croak('open("-| ' . $self->perl . " -V\"): $!");
  my $perl_v = do { local $/; <$pipe> };
  close $pipe or $self->_croak('close("-| ' . $self->perl . " -V\"): $!");

  require Digest::MD5;
  $self->{suppressions_tag} = Digest::MD5::md5_hex($perl_v);
 }

 return $self->{suppressions_tag};
}

sub DESTROY {
 my ($self) = @_;

 my $file = $self->{trainer_file};
 return unless $file and -e $file;

 1 while unlink $file;

 return;
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Command>.

L<Env::Sanctify>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Command::Perl

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Command::Perl

__DATA__
use strict;
use warnings;

BEGIN { require Test::Valgrind; }

use Test::More;

eval {
 require XSLoader;
 XSLoader::load('Test::Valgrind', $Test::Valgrind::VERSION);
};

unless ($@) {
 Test::Valgrind::notleak("valgrind it!");
} else {
 diag $@;
 *Test::Valgrind::DEBUGGING = sub { 'unknown' };
}

plan tests => 1;
fail 'should not be seen';
diag 'debbugging flag is ' . Test::Valgrind::DEBUGGING();

eval {
 require XSLoader;
 XSLoader::load('Test::Valgrind::Fake', 0);
};

diag $@ ? 'Ok' : 'Succeeded to load Test::Valgrind::Fake but should\'t';

require List::Util;

my @cards = List::Util::shuffle(0 .. 51);

{
 package Test::Valgrind::Test::Fake;

 use base qw/strict/;
}

eval 'use Time::HiRes qw/usleep/';
