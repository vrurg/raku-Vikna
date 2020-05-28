use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Coord> - role representing a 2D coordinate

=DESCRIPTION

Only defines attributes C<Int:D $.x> and C<Int:D $.y>.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

unit role Vikna::Coord;

has Int:D $.x = 0;
has Int:D $.y = 0;
