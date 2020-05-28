use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Color::Named> - a role representing named colors

=DESCRIPTION

Stringifies into the given color name.

=ATTRIBUTES

=head3 C<Str:D $.name>

Color name used to create the object.

=METHODS

=head3 C<rgb-by-name(Str:D $name)>

If color with given C<$name> is known then return a L<C<Hash>|https://docs.raku.org/type/Hash> with keys C<r>, C<g>, C<b>.
Otherwise returns empty hash.

=head3 C<known-color-name($name)>

Returns I<True> if color C<$name> is known.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,
L<C<Vikna::Color>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Color.md>,
L<C<Color::Names>|https://modules.raku.org/dist/Color::Names>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

use Color::Names;

my %color-data = Color::Names.color-data(<X11 XKCB CSS>);

unit role Vikna::Color::Named;

has Str:D $.name is required;

method rgb-by-name(Str:D $name) {
    return %() unless %color-data{$name}:exists;
    my $crecord = %color-data{$name};
    %( <r g b> Z=> $crecord<rgb><> )
}

method known-color-name($name) {
    # ? self!lookup-name($name)
    %color-data{$name}:exists
}

method Str { $!name }
