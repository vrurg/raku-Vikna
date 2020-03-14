use v6.e.PREVIEW;

unit class Vikna::CAttr;

has $.fg is rw;
has $.bg is rw;
has $.pattern is rw;

proto cattr(|) is export {*}
multi cattr($fg, $bg?, $pattern?) {
    Vikna::CAttr.new(:$fg, :$bg, :$pattern)
}
multi cattr(*%profile) {
    Vikna::CAttr.new(|%profile)
}
