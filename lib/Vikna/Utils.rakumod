use v6.e.PREVIEW;
unit module Vikna::Utils;

subset Dimension of Int:D is export where * > 0;
subset BasicColor of Any is export where Any:U | Str:D;

# Mouse button codes
constant MBNone   is export = 0;
constant MBLeft   is export = 1;
constant MBMiddle is export = 2;
constant MBRight  is export = 3;

# Text style codes (VS*: Vikna Style)
# Styles are recorded on Canvas as a single char. The char is formed of ([+|] VSBase, @styles).chr. VSBase is set to
# 0x20 to form printable chars and because VSBase +| VSDefault is the space character which means "no styles".
# Correspondingly, where applicable, '' or undefined value means transparent style, same as for colors.
constant VSTransparent is export = 0x00;
constant VSBase        is export = 0x20;
# Provide VSNone for readability
constant VSNone        is export = 0x20;
constant VSDefault     is export = 0x00;
constant VSBold        is export = 0x01;
constant VSItalic      is export = 0x02;
constant VSUnderline   is export = 0x04;
constant VSMask        is export = 0x07;
constant VSBaseMask    is export = 0x27;

our %VSBits is export = :bold(VSBold), :italic(VSItalic), :underline(VSUnderline);
our %VSNames is export = %VSBits.invert;

# HoldCollect – preserve all events of a type
# HoldFirst – preserve only first event of a type
# HoldLast – preserve only the last event of a type
enum EvHoldKind is export <HoldCollect HoldFirst HoldLast>;

# Widget children strata
enum ChildStrata is export «:StBack(0) StMain StModal»;

### Exported subs ###

# Make Int representation of a style from various sources
proto sub to-style(| --> Int) is export {*}
# One way to set a transparent style is to to-style(VSTransparent) or just don't have the VSBase bit set.
multi sub to-style(Int:D $style) {
    $style +& VSBase
        ?? $style +& ( VSBase +| VSMask )
        !! VSTransparent
}
multi sub to-style(+@styles) { VSBase +| (( [+|] @styles ) +& VSMask) }
# This is another way to set the transparent style
multi sub to-style('') { 0 }
multi sub to-style(Str:D $style where *.chars == 1) { $style.ord +& VSBaseMask }
# Take a space-separated list of style names
multi sub to-style(Str:D $style) {
    my $int-style = VSTransparent;
    for $style.split(/\s+/) -> $st {
        $int-style +|= VSBase +| $_ with %VSBits{$st}
    }
    $int-style
}
multi sub to-style(Mu:U) { VSTransparent }

# Convert into Canvas style representation
sub to-style-char(\style) is export {
    $_ == VSTransparent ?? '' !! .chr given to-style(style)
}

# Make a list of VS* constants from various sources
sub to-styles(|c) is export {
    my $st = to-style(|c);
    my @styles;
    for VSBold, VSItalic, VSUnderline -> \style-bit {
        @styles.push: style-bit if $st +& style-bit;
    }
    @styles
}
