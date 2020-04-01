use v6.e.PREVIEW;

# Character attributes. Immutable
unit class Vikna::CAttr;

use Vikna::Utils;
use AttrX::Mooish;

has $.fg;
has $.bg;
# Styles, see VS* constants in Vikna::Utils
# If VSBase is not set then the style is trasparent.
has Int $.style = VSTransparent;
has %.Profile is mooish(:lazy);

method new(*%c) {
    nextsame unless %c<style>:exists;
    nextwith |%c, :style(to-style(%c<style>))
}

method clone(*%c) {
    nextsame unless %c<style>:exists;
    nextwith |%c, :style(to-style(%c<style>))
}

method dup(*%c) {
    %c<style> := to-style(%c<style>) if %c<style>:exists;
    self.new: |%!Profile, |%c
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
