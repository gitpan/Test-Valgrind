package Test::Valgrind::Suppressions;

use strict;
use warnings;

=head1 NAME

Test::Valgrind::Suppressions - Placeholder for architecture-dependant perl suppressions.

=head1 VERSION

Version 0.051

=cut

our $VERSION = '0.051';

=head1 DESCRIPTION

L<Test::Valgrind> needs suppressions so that perl's errors aren't reported. However, these suppressions depend widely on the architecture, perl's version and the features it has been build with (e.g. threads). The goal of this module is hence to be installed together with the suppression file generated when the Test-Valgrind distribution was built, and to handle back to L<Test::Valgrind> the path to the suppression file.

=head1 FUNCTIONS

=head2 C<supp_path>

Returns the path to the suppression file that applies to the current running perl, or C<undef> when no such file is available.

=cut

sub supp_path {
 my $pkg = __PACKAGE__;
 $pkg =~ s!::!/!g;
 $pkg .= '.pm';
 return if not $INC{$pkg};
 my $supp = $INC{$pkg};
 $supp =~ s![^/]*$!perlTestValgrind.supp!;
 return (-f $supp) ? $supp : undef;
}

=head1 CONSTANTS

=head2 C<VG_PATH>

The path to the valgrind binary from which the suppressions were generated.

=cut

use constant VG_PATH => undef;

=head1 EXPORT

This module exports the L</supp_path> function and the L</VG_PATH> constants only on demand, either by giving their name explicitely or by the C<:funcs>, C<:consts> or C<:all> tags.

=cut

use base qw/Exporter/;

our @EXPORT         = ();
our %EXPORT_TAGS    = (
 'funcs'  => [ qw/supp_path/ ],
 'consts' => [ qw/VG_PATH/ ]
);
our @EXPORT_OK      = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = [ @EXPORT_OK ];

=head1 SEE ALSO

L<Test::Valgrind>.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on #perl @ FreeNode (vincent or Prof_Vince).

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-valgrind-suppressions at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Valgrind>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Valgrind::Suppressions

=head1 COPYRIGHT & LICENSE

Copyright 2008 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

1; # End of Test::Valgrind::Suppressions
