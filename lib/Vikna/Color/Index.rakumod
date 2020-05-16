use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Color::Index> - represents indexed color

=ATTRIBUTES

=head3 C<Int $.index>

The index used to create the object.

=METHODS

=head3 C<method rgb-by-index(Int:D $idx)>

Takes an ANSI color index and returns its RGB representation as a L<C<Hash>|https://docs.raku.org/type/Hash>
with keys C<r>, C<g>, C<b>. If no such index exists then an empty hash is returned.

I<Note> that the representation is taken from file I<resources/color-index.json>.

Stringifies into index.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md>,
L<C<Vikna::Color>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color.md>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

unit role Vikna::Color::Index;

use JSON::Fast;
use AttrX::Mooish;

has Int $.index;

my $color-idx;

# Take all index => r,g,b mappings from resources/color-index.json
my sub color-idx {
    $color-idx //= from-json %?RESOURCES<color-index.json>.slurp;
}

method rgb-by-index(Int:D $idx) {
    my %rgb;
    with color-idx.[$idx] {
        %rgb = .<rgb>
    }
    %rgb
}

method Str { ~$!index }
