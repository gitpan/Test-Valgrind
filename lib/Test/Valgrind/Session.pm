package Test::Valgrind::Session;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Session - Test::Valgrind session object.

=head1 VERSION

Version 1.10

=cut

our $VERSION = '1.10';

=head1 DESCRIPTION

This class supervises the execution of the C<valgrind> process.
It also acts as a dispatcher between the different components.

=cut

use File::Spec   ();
use Scalar::Util ();

use Fcntl (); # F_SETFD
use POSIX (); # SIGKILL

use version ();

use base qw/Test::Valgrind::Carp/;

=head1 METHODS

=head2 C<< new search_dirs => \@search_dirs, valgrind => [ $valgrind | \@valgrind ], min_version => $min_version, no_def_supp => $no_def_supp, extra_supps => \@extra_supps >>

The package constructor, which takes several options :

=over 4

=item *

All the directories from C<@search_dirs> will have F<valgrind> appended to create a list of candidates for the C<valgrind> executable.

Defaults to the current C<PATH> environment variable.

=item *

If a simple scalar C<$valgrind> is passed as the value to C<'valgrind'>, it will be the only candidate.
C<@search_dirs> will then be ignored.

If an array refernce C<\@valgrind> is passed, its values will be I<prepended> to the list of the candidates resulting from C<@search_dirs>.

=item *

C<$min_version> specifies the minimal C<valgrind> version required.
The constructor will croak if it's not able to find an adequate C<valgrind> from the supplied candidates list and search path.

Defaults to none.

=item *

If C<$no_def_supp> is false, C<valgrind> won't read the default suppression file associated with the tool and the command.

Defaults to false.

=item *

C<$extra_supps> is a reference to an array of optional suppression files that will be passed to C<valgrind>.

Defaults to none.

=back

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 my @paths;
 my $vg = delete $args{valgrind};
 if (defined $vg and not ref $vg) {
  @paths = ($vg);
 } else {
  push @paths, @$vg if $vg and ref $vg eq 'ARRAY';
  my $dirs = delete $args{search_dirs};
  $dirs = [ File::Spec->path ] unless $dirs;
  push @paths, map File::Spec->catfile($_, 'valgrind'), @$dirs
                                                        if ref $dirs eq 'ARRAY';
 }
 $class->_croak('Empty valgrind candidates list') unless @paths;

 my $min_version = delete $args{min_version};
 defined and not ref and $_ = version->new($_) for $min_version;

 my ($valgrind, $version);
 for (@paths) {
  next unless -x;
  my $ver = qx/$_ --version/;
  if ($ver =~ /^valgrind-(\d+(\.\d+)*)/) {
   if ($min_version) {
    $version = version->new($1);
    next if $version < $min_version;
   } else {
    $version = $1;
   }
   $valgrind = $_;
   last;
  }
 }
 $class->_croak('No appropriate valgrind executable could be found')
                                                       unless defined $valgrind;

 my $extra_supps = delete $args{extra_supps};
 $extra_supps    = [ ] unless $extra_supps and ref $extra_supps eq 'ARRAY';
 @$extra_supps   = grep { defined && -f $_ && -r _ } @$extra_supps;

 bless {
  valgrind    => $valgrind,
  version     => $version,
  no_def_supp => delete($args{no_def_supp}),
  extra_supps => $extra_supps,
 }, $class;
}

=head2 C<valgrind>

The path to the selected C<valgrind> executable.

=head2 C<version>

The L<version> object associated to the selected C<valgrind>.

=cut

sub version {
 my ($self) = @_;

 my $version = $self->{version};
 $self->{version} = $version = version->new($version) unless ref $version;

 return $version;
}

=head2 C<no_def_supp>

Read-only accessor for the C<no_def_supp> option.

=cut

eval "sub $_ { \$_[0]->{$_} }" for qw/valgrind no_def_supp/;

=head2 C<extra_supps>

Read-only accessor for the C<extra_supps> option.

=cut

sub extra_supps { @{$_[0]->{extra_supps} || []} }

=head2 C<< run action => $action, tool => $tool, command => $command >>

Runs the command C<$command> through C<valgrind> with the tool C<$tool>, which will report to the action C<$action>.

If the command is a L<Test::Valgrind::Command::Aggregate> object, the action and the tool will be initialized once before running all the aggregated commands.

=cut

sub run {
 my $self = shift;

 my %args = @_;

 $self->start(%args);
 my $guard = bless sub { $self->finish } => 'Test::Valgrind::Session::Guard';

 $self->_run($args{command});
}

sub _run {
 my ($self, $cmd) = @_;

 if ($cmd->isa('Test::Valgrind::Command::Aggregate')) {
  $self->_run($_) for $cmd->commands;
  return;
 }

 $self->command($cmd);

 $self->report($self->report_class->new_diag(
  'Using valgrind ' . $self->version . ' located at ' . $self->valgrind
 ));

 my $env = $self->command->env($self);

 my @supp_args;
 if ($self->do_suppressions) {
  push @supp_args, '--gen-suppressions=all';
 } elsif (not $self->no_def_supp) {
  my $def_supp = $self->def_supp_file;
  if (defined $def_supp and not -e $def_supp) {
   $self->report($self->report_class->new_diag(
    "Generating suppressions..."
   ));
   require Test::Valgrind::Suppressions;
   Test::Valgrind::Suppressions->generate(
    tool    => $self->tool,
    command => $self->command,
    target  => $def_supp,
   );
   $self->_croak('Couldn\'t generate suppressions') unless -e $def_supp;
   $self->report($self->report_class->new_diag(
    "Suppressions for this perl stored in $def_supp"
   ));
  }
  push @supp_args, '--suppressions=' . $_ for $self->suppressions;
 }

 pipe my $vrdr, my $vwtr or $self->_croak("pipe(\$vrdr, \$vwtr): $!");
 {
  my $oldfh = select $vrdr;
  $|++;
  select $oldfh;
 }

 my $pid = fork;
 $self->_croak("fork(): $!") unless defined $pid;

 if ($pid == 0) {
  eval 'setpgrp 0, 0';
  close $vrdr or $self->_croak("close(\$vrdr): $!");
  fcntl $vwtr, Fcntl::F_SETFD(), 0
                              or $self->_croak("fcntl(\$vwtr, F_SETFD, 0): $!");

  my @args = (
   $self->valgrind,
   $self->tool->args($self),
   @supp_args,
   $self->parser->args($self, $vwtr),
   $self->command->args($self),
  );

#  $self->report($self->report_class->new_diag("@args"));

  exec { $args[0] } @args or $self->_croak("exec @args: $!");
 }

 local $SIG{INT} = sub {
  kill -(POSIX::SIGKILL()) => $pid;
  waitpid $pid, 0;
  die 'interrupted';
 };

 close $vwtr or $self->_croak("close(\$vwtr): $!");

 $self->parser->parse($self, $vrdr);

 $self->{exit_code} = (waitpid($pid, 0) == $pid) ? $? >> 8 : 255;

 close $vrdr or $self->_croak("close(\$vrdr): $!");

 return;
}

sub Test::Valgrind::Session::Guard::DESTROY { $_[0]->() }

=head2 C<action>

Read-only accessor for the C<action> associated to the current run.

=head2 C<tool>

Read-only accessor for the C<tool> associated to the current run.

=head2 C<parser>

Read-only accessor for the C<parser> associated to the current tool.

=head2 C<command>

Read-only accessor for the C<command> associated to the current run.

=cut

my @members;
BEGIN {
 @members = qw/action tool command parser/;
 for (@members) {
  eval "sub $_ { \@_ <= 1 ? \$_[0]->{$_} : (\$_[0]->{$_} = \$_[1]) }";
  die if $@;
 }
}

=head2 C<do_suppressions>

Forwards to C<< ->action->do_suppressions >>.

=cut

sub do_suppressions { $_[0]->action->do_suppressions }

=head2 C<report_class>

Calls C<< ->action->report_class >> with the current session object as the unique argument.

=cut

sub report_class { $_[0]->tool->report_class($_[0]) }

=head2 C<def_supp_file>

Returns an absolute path to the default suppression file associated to the current session.

C<undef> will be returned as soon as any of C<< ->command->suppressions_tag >> or C<< ->tool->suppressions_tag >> are also C<undef>.
Otherwise, the file part of the name is builded by joining those two together, and the directory part is roughly F<< File::HomeDir->my_home / .perl / Test-Valgrind / suppressions / $VERSION >>.

=cut

sub def_supp_file {
 my ($self) = @_;

 my $tool_tag = $self->tool->suppressions_tag($self);
 return unless defined $tool_tag;

 my $cmd_tag = $self->command->suppressions_tag($self);
 return unless defined $cmd_tag;

 require File::HomeDir; # So that it's not needed at configure time.

 return File::Spec->catfile(
  File::HomeDir->my_home,
  '.perl',
  'Test-Valgrind',
  'suppressions',
  $VERSION,
  "$tool_tag-$cmd_tag.supp",
 );
}

=head2 C<suppressions>

Returns the list of all the suppressions that will be passed to C<valgrind>.
Honors L</no_def_supp> and L</extra_supps>.

=cut

sub suppressions {
 my ($self) = @_;

 my @supps;
 unless ($self->no_def_supp) {
  my $def_supp = $self->def_supp_file;
  push @supps, $def_supp if defined $def_supp;
 }
 push @supps, $self->extra_supps;

 return @supps;
}

=head2 C<start>

Starts the action and tool associated to the current run.
It's automatically called at the beginning of L</run>.

=cut

sub start {
 my $self = shift;

 my %args = @_;

 for (qw/action tool command/) {
  my $base = 'Test::Valgrind::' . ucfirst;
  my $value = $args{$_};
  $self->_croak("Invalid $_") unless Scalar::Util::blessed($value)
                                                         and $value->isa($base);
  $self->$_($args{$_})
 }

 delete @{$self}{qw/last_status exit_code/};

 $self->tool->start($self);
 $self->parser($self->tool->parser_class($self)->new)->start($self);
 $self->action->start($self);

 return;
}

=head2 C<abort $msg>

Forwards to C<< ->action->abort >> after unshifting the session object to the argument list.

=cut

sub abort {
 my $self = shift;

 $self->action->abort($self, @_);
}

=head2 C<report $report>

Forwards to C<< ->action->report >> after unshifting the session object to the argument list.

=cut

sub report {
 my ($self, $report) = @_;

 return unless defined $report;

 for my $handler (qw/tool command/) {
  $report = $self->$handler->filter($self, $report);
  return unless defined $report;
 }

 $self->action->report($self, $report);
}

=head2 C<finish>

Finishes the action and tool associated to the current run.
It's automatically called at the end of L</run>.

=cut

sub finish {
 my ($self) = @_;

 my $action = $self->action;

 $action->finish($self);
 $self->parser->finish($self);
 $self->tool->finish($self);

 my $status = $action->status($self);
 $self->{last_status} = defined $status ? $status : $self->{exit_code};

 $self->$_(undef) for @members;

 return;
}

=head2 C<status>

Returns the status code of the last run of the session.

=cut

sub status { $_[0]->{last_status} }

=head1 SEE ALSO

L<Test::Valgrind>, L<Test::Valgrind::Action>, L<Test::Valgrind::Command>, L<Test::Valgrind::Tool>, L<Test::Valgrind::Parser>.

L<version>, L<File::HomeDir>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Session

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Session
