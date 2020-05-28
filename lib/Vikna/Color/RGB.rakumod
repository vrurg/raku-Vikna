use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Color::RGB> - a role for RGB representation of a color

=DESCRIPTION

Only defines stringification of the object into RGB triplet.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,
L<C<Vikna::Color>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Color.md>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

unit role Vikna::Color::RGB;

method Str {
    $.rgb.join(",")
}
