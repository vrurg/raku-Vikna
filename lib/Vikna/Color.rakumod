use v6.e.PREVIEW;
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

class CSTR-Actions {
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
