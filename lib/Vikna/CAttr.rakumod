use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::CAttr> - on screen symbol attributes

=DESCRIPTION

Class defines basic attributes of a symbol on screen: it's foreground and background colors, and style.

=ATTRIBUTES

=head3 C<$.fg>

Foreground color

=head3 C<$.bg>

Bacground color

=head3 C<Int $.style>

Style of the symbol. See C<VS*> constants in L<C<Vikna::Utils>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Utils.md>.

=head3 C<%.Profile>

Cached representation of the attribute suitable for passing into methods like
L<C<Vikna::Canvas>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Canvas.md>C<::imprint>.

=METHODS

=head3 C<new(*%c)>
=head3 C<clone(*%c)>
=head3 C<dup(*%c)>

All three methods preserve their usual meaning with one nuance: if C<style> key is passed in C<%c> profile then it
gets normalized using C<to-style> routine from L<C<Vikna::Utils>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Utils.md>.

=head3 C<bold()>, C<italic()>, C<underline()>

Methods return I<True> if corresponding style is set.

=head3 C<transparent()>

Returns I<True> style is transparent.

=head3 C<style-char()>

Returns style representation as a single char. For example, for non-transparent style if nothing is set it would be just
space character I<" "> (code I<0x20> which is the value of C<VSNone> constant). For bold which is represented as
C<VSBase +| VSBold> it will be exclamation mark I<"!"> (code I<0x21>).

=head3 C<styles()>

Returns a list of style C<VS*> constants.

=ROUTINES

=head3 C<multi sub cattr($fg, $bg?, $style?)>
=head3 C<multi sub cattr(:$fg, :$bg, :$style)>

A shortcut to create a new C<Vikna::CAttr> instance.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

# Character attributes. Immutable
unit class Vikna::CAttr;

use Vikna::Color;
use Vikna::Utils;
use AttrX::Mooish;

has $.fg;
has $.bg;
# Styles, see VS* constants in Vikna::Utils
# If VSBase is not set then the style is trasparent.
has Int $.style = VSTransparent;
has %.Profile is mooish(:lazy);

my sub normalize-profile(%profile is copy) {
    %profile<style> = to-style(%profile<style>) if %profile<style>:exists;
    for <fg bg> -> $color {
        if %profile{$color}:exists {
            with %profile{$color} {
                %profile{$color} = ($_ ~~ Str ?? ~(Vikna::Color.parse(%profile{$color}) // $_) !! $_);
            }
        }
    }
    %profile
}

method new(*%c) {
    nextwith |normalize-profile(%c)
}

method clone(*%c) {
    nextwith |normalize-profile(%c)
}

method dup(*%c) {
    self.new: |%!Profile, |normalize-profile(%c)
}

method build-Profile {
    %( :$!fg, :$!bg, :$!style )
}

method bold {
    ? $!style && $!style +& VSBold
}

method italic {
    ? $!style && $!style &+ VSItalic
}

method underline {
    ? $!style && $!style &+ VSUnderline
}

method transparent {
    !($!style && $!style +& VSBase)
}

method style-char { $!style.chr }

# Return a list of style codes
method styles {
    to-styles($!style)
}

proto cattr(|) is export {*}
multi cattr($fg, $bg?, $style?) {
    ::?CLASS.new(:$fg, :$bg, :$style)
}
multi cattr(*%profile) {
    ::?CLASS.new(|%profile)
}

method Str {
    "fg:" ~ ($!fg ?? $!fg.Str !! '*transparent*')
    ~ " bg:" ~ ($!bg ?? $!bg.Str !! '*transparent*')
    ~ " style=" ~ $!style.fmt('0x%02x')
}