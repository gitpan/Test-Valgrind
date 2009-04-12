package Test::Valgrind::Tool::memcheck;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Tool::memcheck - Run an analysis through the memcheck tool.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

=head1 DESCRIPTION

This tool parses the XML output of a C<memcheck> run with L<XML::Twig>.

=cut

use base qw/Test::Valgrind::Tool::SuppressionsParser Test::Valgrind::Tool/;

=head1 METHODS

This class inherits L<Test::Valgrind::Tool> and L<Test::Valgrind::Tool::SuppressionsParser>.

=head2 C<requires_version>

This tool requires C<valgrind> C<3.1.0>.

=cut

sub requires_version { '3.1.0' }

=head2 C<< new callers => $callers, ... >>

Your usual constructor.

C<$callers> specifies the number of stack frames to inspect for errors : the bigger you set it, the more granular the analysis is.

Other arguments are passed straight to C<< Test::Valgrind::Tool->new >>.

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 my $callers = delete $args{callers} || 12;
 $callers =~ s/\D//g;

 my $self = bless $class->Test::Valgrind::Tool::new(%args), $class;

 $self->{callers} = $callers;

 $self->{twig} = Test::Valgrind::Tool::memcheck::Twig->new(tool => $self);

 $self;
}

sub new_trainer { shift->new(callers => 50) }

=head2 C<callers>

Read-only accessor for the C<callers> option.

=cut

sub callers { $_[0]->{callers} }

=head2 C<twig>

Read-only accessor for the underlying L<XML::Twig> parser.

=cut

sub twig    { $_[0]->{twig} }

sub suppressions_tag { 'memcheck-' . $_[1]->version }

=head2 C<report_class_analysis $session>

This tool emits C<Test::Valgrind::Tool::memcheck::Report> object reports in analysis mode.

=cut

sub report_class_analysis { 'Test::Valgrind::Tool::memcheck::Report' }

sub args {
 my ($self, $sess) = @_;

 my @args = (
  '--tool=memcheck',
  '--leak-check=full',
  '--leak-resolution=high',
  '--show-reachable=yes',
  '--num-callers=' . $self->callers,
  '--error-limit=yes',
 );

 unless ($sess->do_suppressions) {
  push @args, '--track-origins=yes' if $sess->version ge '3.4.0';
  push @args, '--xml=yes';
 }

 push @args, $self->SUPER::args();

 return @args;
}

# We must store the session in ourselves because it's only possible to pass
# arguments to XML::Twig objects by a global stash.

sub _session { @_ <= 1 ? $_[0]->{_session} : ($_[0]->{_session} = $_[1]) }

sub start {
 my ($self, $sess) = @_;

 $self->_croak('This memcheck tool can\'t be run in two sessions at once')
                                                             if $self->_session;

 $self->SUPER::start($sess);
 $self->_session($sess);

 return;
}

sub parse_analysis {
 my ($self, $sess, $fh) = @_;

 my $twig = $self->twig;
 $twig->parse($fh);
 $twig->purge;

 return;
}

sub finish {
 my ($self, $sess) = @_;

 $self->_session(undef);
 $self->SUPER::start($sess);

 return;
}

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Tool>, L<Test::Valgrind::Tool::SuppressionsParser>.

L<XML::Twig>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Tool::memcheck

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

# End of Test::Valgrind::Tool::memcheck

package Test::Valgrind::Tool::memcheck::Report;

use base qw/Test::Valgrind::Report/;

use Config qw/%Config/;

our $VERSION = '1.00';

my @kinds = qw/
 InvalidFree
 MismatchedFree
 InvalidRead
 InvalidWrite
 InvalidJump
 Overlap
 InvalidMemPool
 UninitCondition
 UninitValue
 SyscallParam
 ClientCheck
 Leak_DefinitelyLost
 Leak_IndirectlyLost
 Leak_PossiblyLost
 Leak_StillReachable
/;
push @kinds, __PACKAGE__->SUPER::kinds();

my %kinds_hashed = map { $_ => 1 } @kinds;

sub kinds      { @kinds }

sub valid_kind { exists $kinds_hashed{$_[1]} }

sub is_leak    { $_[0]->kind =~ /^Leak_/ ? 1 : '' }

my $pad = 2 * ($Config{ptrsize} || 4);

sub dump {
 my ($self) = @_;

 my $data = $self->data;

 my $desc = '';

 for ([ '', 2, 4 ], [ 'aux', 4, 6 ], [ 'orig', 4, 6 ]) {
  my ($prefix, $wind, $sind) = @$_;

  my ($what, $stack) = @{$data}{"${prefix}what", "${prefix}stack"};
  next unless defined $what and defined $stack;

  $_ = ' ' x $_ for $wind, $sind;

  $desc .= "$wind$what\n";
  for (@$stack) {
   my ($ip, $obj, $fn, $dir, $file, $line) = map { (defined) ? $_ : '?' } @$_;
   my $frame;
   if ($fn eq '?' and $obj eq '?') {
    $ip =~ s/^0x//g;
    $ip = hex $ip;
    $frame = sprintf "0x%0${pad}X", $ip;
   } else {
    $frame = sprintf '%s (%s) [%s:%s]', $fn, $obj, $file, $line;
   }
   $desc .= "$sind$frame\n";
  }
 }

 return $desc;
}

# End of Test::Valgrind::Tool::memcheck::Report

package Test::Valgrind::Tool::memcheck::Twig;

our $VERSION = '1.00';

use Scalar::Util;

use base qw/XML::Twig Test::Valgrind::Carp/;

BEGIN { XML::Twig->add_options('Stash'); }

my %handlers = (
 '/valgrindoutput/error' => \&handle_error,
);

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;
 my $stash = delete $args{stash} || { };

 my $tool = delete $args{tool};
 $class->_croak('Invalid tool') unless Scalar::Util::blessed($tool)
                                         and $tool->isa('Test::Valgrind::Tool');
 $stash->{tool} = $tool;

 bless $class->XML::Twig::new(
  elt_class     => __PACKAGE__ . '::Elt',
  stash         => $stash,
  twig_roots    => { map { $_ => 1             } keys %handlers },
  twig_handlers => { map { $_ => $handlers{$_} } keys %handlers },
 ), $class;
}

sub stash { shift->{Stash} }

sub handle_error {
 my ($twig, $node) = @_;

 my $id   = $node->kid('unique')->text;
 my $kind = $node->kid('kind')->text;

 my $data;

 $data->{what}  = $node->kid('what')->text;
 $data->{stack} = [ map $_->listify_frame,
                                       $node->kid('stack')->children('frame') ];

 for (qw/leakedbytes leakedblocks/) {
  my $kid = $node->first_child($_);
  next unless $kid;
  $data->{$_} = int $kid->text;
 }

 if (my $auxwhat = $node->first_child('auxwhat')) {
  if (my $stack = $auxwhat->next_sibling('stack')) {
   $data->{auxstack} = [ map $_->listify_frame, $stack->children('frame') ];
  }
  $data->{auxwhat} = $auxwhat->text;
 }

 if (my $origin = $node->first_child('origin')) {
  $data->{origwhat}  = $origin->kid('what')->text;
  $data->{origstack} = [ map $_->listify_frame,
                                     $origin->kid('stack')->children('frame') ];
 }

 my $report = Test::Valgrind::Tool::memcheck::Report->new(
  kind => $kind,
  id   => $id,
  data => $data,
 );

 $twig->stash->{tool}->_session->report($report);

 $twig->purge;
}

# End of Test::Valgrind::Tool::memcheck::Twig

package Test::Valgrind::Tool::memcheck::Twig::Elt;

our $VERSION = '1.00';

BEGIN { require XML::Twig; }

use base qw/XML::Twig::Elt Test::Valgrind::Carp/;

sub kid {
 my ($self, $what) = @_;
 my $node = $self->first_child($what);
 $self->_croak("Couldn't get first $what child node") unless $node;
 return $node;
}

sub listify_frame {
 my ($frame) = @_;

 return unless $frame->tag eq 'frame';

 return [
  map {
   my $x = $frame->first_child($_);
   $x ? $x->text : undef
  } qw/ip obj fn dir file line/
 ];
}

1; # End of Test::Valgrind::Tool::memcheck::Twig::Elt
