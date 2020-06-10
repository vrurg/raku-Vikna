use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Color> - support for different formats of colors

=SYNOPSIS

    my $color = Vikna::Color.parse: '#abc'; # RGB 0xAA, 0xBB, 0xCC
    $color = Vikna::Color.parse: '42, 255, 13';
    $color = Vikna::Color.parse: 'rgba: .1, .2, .3, .5';

=DESCRIPTION

Inherits from L<C<Color>|https://modules.raku.org/dist/Color>.

This class function is to provide interface for working with string representation of colors. It supports colors in the
following forms:

=item ANSI index: I<123>
=item web: I<#00aa80>, I<#abc>
=item named: I<green>
=item RGB triplet: I<255,0,128>
=item RGB decimal triplet: I<1, 0.1, .5>
=item prefixed form: I<rgba: 1, 0.5, 0.9, 0.3>

For prefixed form knwon prefixes are I<rgb>, I<rgbd>, I<rgba>, I<rgbad>, I<cmyk>, I<hsl>, I<hsla>, I<hsv>, I<hsva> -
following the key names supported by L<C<Color>|https://modules.raku.org/dist/Color> class.

The only method to mention is C<parse> which takes a string a returns either a C<Vikna::Color> instance or a Nil if
the color string is invalid. To be more precise, the object returned will have with one of C<Vikna::Color> roles mixed
in:
L<C<Vikna::Color::Index>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/Index.md>,
L<C<Vikna::Color::Named>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/Named.md>,
L<C<Vikna::Color::RGB>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/RGB.md>,
L<C<Vikna::Color::RGBA>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/RGBA.md>.
The difference between the four is in the way they strigify by default and additional methods provided depending on the
format.

Apparently, API provided by L<C<Coloar>|https://modules.raku.org/dist/Coloar> is available too.

=head2 Caching

Color objects are cached internally to speed up color lookups. But it also means that same color object could be
returned for two equivalent color strings. Nevertheless, the equivalence of the objects is not guaranteed due to
limited cache size.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>,
L<C<Color>|https://modules.raku.org/dist/Color>,
L<C<Color::Names>|https://modules.raku.org/dist/Color::Names>,
L<C<Vikna::Color::Index>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/Index.md>,
L<C<Vikna::Color::Named>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/Named.md>,
L<C<Vikna::Color::RGB>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/RGB.md>,
L<C<Vikna::Color::RGBA>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color/RGBA.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

unit class Vikna::Color;

use Color;
use Color::Names;
use Cache::Async;

use Vikna::Object;
use Vikna::Color::Named;
use Vikna::Color::Index;
use Vikna::Color::RGB;
use Vikna::Color::RGBA;
use Vikna::X;

also is Color;

my %cpfx =
    # Where ch-type is empty it could be autodetected
    rgb   => { :ch-type(''),  :ch-count(3), :role(Vikna::Color::RGB),  },
    rgbd  => { :ch-type<Rat>, :ch-count(3), :role(Vikna::Color::RGB),  },
    rgba  => { :ch-type(''),  :ch-count(4), :role(Vikna::Color::RGBA), },
    rgbad => { :ch-type<Rat>, :ch-count(3), :role(Vikna::Color::RGBA), },
    cmyk  => { :ch-type<Rat>, :ch-count(3), :role(Vikna::Color::RGB),  },
    hsl   => { :ch-type<Int>, :ch-count(3), :role(Vikna::Color::RGB),  },
    hsla  => { :ch-type<Int>, :ch-count(4), :role(Vikna::Color::RGBA), },
    hsv   => { :ch-type<Int>, :ch-count(3), :role(Vikna::Color::RGB),  },
    hsva  => { :ch-type<Int>, :ch-count(4), :role(Vikna::Color::RGBA), },
    ;

# Caching is used not only to speedup object creation but also to re-utilize same color object for the same color string.
my $cache;

my sub cache-color-producer($key, Capture:D \c) {
    my $c = Vikna::Color.new: |c;
    $c
}

INIT $cache = Cache::Async.new(:producer(&cache-color-producer), :max-size(10000));

my grammar ColorStr {
    token TOP {
        <color>
    }

    token hs { \h* }

    proto token color {*}
    multi token color:sym<web> {
        <.hs> '#' [ $<hex> = [ <.xdigit> ** 3..8 ] <?{ $<hex>.chars == 3 | 4 | 6 | 8 }> ] <.hs> $
    }
    multi token color:sym<pfx> {
        :my $*CH-TYPE = '';
        :my $*CH-COUNT = 0;
        <.hs> <kind> ':' <.hs> <cchannel> ** {$*CH-COUNT} % <list-sep>
    }
    multi token color:sym<triplet> {
        :my $*CH-TYPE = '';
        :my $*CH-COUNT = 3;
        <.hs> <cchannel> ** 3 % <list-sep>
    }
    multi token color:sym<index> {
        \d ** 1..3 <?{ $/.Int < 256 }>
    }
    multi token color:sym<name> {
        <alpha> \w* <?{ Vikna::Color::Named.known-color-name(~$/) }>
    }

    token list-sep {
        <.hs> ',' <.hs>
    }

    token kind {
        \w+ <?{
            with %cpfx{~$/} {
                $*CH-TYPE = .<ch-type>;
                $*CH-COUNT = .<ch-count>;
                True
            }
            else {
                False
            }
        }>
    }

    proto token cchannel {*}
    multi token cchannel:sym<int> {
        \d ** 1..3 <!before '.'>
        <.chan-is(<Int>)>
        <?{ $/.Int < 256 }>
    }
    multi token cchannel:sym<rat> {
        $<int-part> = \d* '.' $<fraction> = \d*
        <?{ $<int-part>.chars || $<fraction>.chars }>
        <.chan-is(<Rat>)>
    }

    method chan-is($ch-type) {
        $*CH-TYPE = $ch-type unless $*CH-TYPE;
        $*CH-TYPE ne $ch-type ?? self.new !! self
    }
}

my class CSTR-Actions {
    has $.no-cache;

    method TOP($/) {
        make $/<color>.made
    }

    method !new-color($cache-key, |c) {
        # note "new color: ", c.raku;
        $!no-cache ?? Vikna::Color.new(|c) !! await $cache.get($cache-key, c)
    }

    method color:sym<web>($/) {
        # 4 colors mean alpha channel
        my $has-alpha = ($/<hex>.chars gcd 4) == 4;
        my $web = ~$/;
        my $named-key = ($has-alpha ?? 'weba' !! 'web');
        make self!new-color( $web, |($named-key => $web) );
    }

    method color:sym<name>($/) {
        make self!new-color($_, :name(~$/)) given ~$/;
    }

    method color:sym<pfx>($/) {
        my $kind = $/<kind>;
        my @ch = $/<cchannel>.map: *.made;
        $kind ~= 'd' if ($kind eq 'rgb' | 'rgba') && (@ch[0] ~~ Num | Rat);
        my $role = %cpfx{$kind}<role>;
        my $cache-key = $kind ~ ":" ~ @ch.join(",");
        make self!new-color($cache-key, :$role, |($kind => @ch));
    }

    method color:sym<triplet>($/) {
        my @ch = $/<cchannel>.map: *.made;
        my $kind = 'rgb' ~ ( @ch[0] ~~ Int ?? '' !! 'd' );
        my $cache-key = $kind ~ ":" ~ @ch.join(",");
        make self!new-color($cache-key, :role(Vikna::Color::RGB), |($kind => @ch))
    }

    method color:sym<index>($/) {
        my $index = $/.Int;
        make self!new-color(~$index, :$index);
    }

    method cchannel:sym<int>($/) {
        make $/.Int
    }

    method cchannel:sym<rat>($/) {
        # Append 0 because .Num coercion doesn't support 10. form of a fractional number.
        my $fraction = (.Str with $/<fraction>) || '0';
        my $int-part = (.Str with $/<int-part>) || '0';
        make ($int-part ~ "." ~ $fraction).Num;
    }
}

method parse(Str:D $scolor, :$no-cache) {
    my $res = ColorStr.parse($scolor, :actions(CSTR-Actions.new(:$no-cache)));
    return Nil unless $res && $res.made;
    $res.made
}

method is-valid(Str:D $scolor, :$empty-ok = False, :$parse-only?) {
    my $valid = (!$scolor && $empty-ok)
                || ($parse-only
                    ?? ColorStr.parse($scolor)
                    !! do {
                        my $res = try ColorStr.parse($scolor, :actions(CSTR-Actions.new));
                        ? ($res && $res.made)
                    });
    $valid
}

# proto method new(|) {*}

multi method new(Str:D :$name, *%c) {
    my %rgb = Vikna::Color::Named.rgb-by-name($name);
    if %rgb {
        (Vikna::Color but Vikna::Color::Named).Color::new(|%rgb, :$name, |%c);
    }
    else {
        Nil
    }
}

multi method new(Int:D :$index, *%c) {
    my %rgb = Vikna::Color::Index.rgb-by-index($index);
    (Vikna::Color but Vikna::Color::Index).Color::new(|%rgb, :$index, |%c);
}

multi method new(Str:D :$web, *%c) {
    (Vikna::Color but Vikna::Color::RGB).new($web, |%c)
}

multi method new(Str:D :$weba, *%c) {
    (Vikna::Color but Vikna::Color::RGBA).new($weba, |%c)
}

multi method new(*%c where { .<role>:exists }) {
    my $role = %c<role>:delete;
    (Vikna::Color but $role).new(|%c)
}

multi method new(:$r!, :$g!, :$b!, *%c) {
    my $role := %c<a>:exists ?? Vikna::Color::RGBA !! Vikna::Color::RGB;
    (Vikna::Color but $role).Color::new(:$r, :$g, :$b, |%c)
}

# Operators

multi infix:<==>(Vikna::Color:D $a, Vikna::Color:D $b) is export {
    $a.r == $b.r && $a.g == $b.g && $a.b == $b.g && $a.alpha == $b.alpha
}
