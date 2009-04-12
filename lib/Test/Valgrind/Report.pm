package Test::Valgrind::Report;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Report - Base class for Test::Valgrind error reports.

=head1 VERSION

Version 1.00

=cut

our $VERSION = '1.00';

use base qw/Test::Valgrind::Carp/;

=head2 C<< new kind => $kind, id => $id, data => $data >>

Your usual constructor.

All options are mandatory :

=over 4

=item *

C<kind> is the category of the report.

=item *

C<id> is an unique identifier for the report.

=item *

C<data> is the content.

=back

=cut

sub new {
 my $class = shift;
 $class = ref($class) || $class;

 my %args = @_;

 my $kind = delete $args{kind};
 $class->_croak("Invalid kind $kind for $class")
                                               unless $class->valid_kind($kind);

 my $id = delete $args{id};
 $class->_croak("Invalid identifier $id") unless defined $id and not ref $id;

 my $data = delete $args{data};

 bless {
  kind => $kind,
  id   => $id,
  data => $data,
 }, $class;
}

=head2 C<< new_diag $data >>

Constructs an object with kind C<'Diag'>, an auto-incremented identifier and the given C<$data>.

=cut

my $diag_id = 0;

sub new_diag { shift->new(kind => 'Diag', id => ++$diag_id, data => $_[0]) }

=head2 C<kind>

Read-only accessor for the C<kind> option.

=cut

sub kind { $_[0]->{kind} }

=head2 C<id>

Read-only accessor for the C<id> option.

=cut

sub id { $_[0]->{id} }

=head2 C<data>

Read-only accessor for the C<data> option.

=cut

sub data { $_[0]->{data} }

=head2 C<is_diag>

Tells if a report has the C<'Diag'> kind, i.e. is a diagnostic.

=cut

sub is_diag { $_[0]->kind eq 'Diag' }

=head2 C<kinds>

Returns the list of valid kinds for this report class.

Defaults to C<'Diag'>.

=cut

sub kinds { 'Diag' }

=head2 C<valid_kind $kind>

Tells whether C<$kind> is a valid kind for this report class.

Defaults to true iff C<$kind eq 'Diag'>.

=cut

sub valid_kind { $_[1] eq 'Diag' }

=head1 SEE ALSO

L<Test::Valgrind>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on C<irc.perl.org> (vincent).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.
I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Report

=head1 COPYRIGHT & LICENSE

Copyright 2009 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Report
