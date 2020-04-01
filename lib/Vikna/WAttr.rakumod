use v6.e.PREVIEW;

# Widget default attributes
unit class Vikna::WAttr;

use Vikna::CAttr;
use Vikna::Utils;

also is Vikna::CAttr;

has $.pattern is rw;

method build-Profile {
    %( :$!pattern, |callsame )
}

proto wattr(|) is export {*}
multi wattr($fg, $bg?, $style?, $pattern?) {
    ::?CLASS.new(:$fg, :$bg, :$style, :$pattern)
}
multi wattr(*%profile) {
    ::?CLASS.new(|%profile)
}
