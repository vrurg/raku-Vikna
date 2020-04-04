use v6.e.PREVIEW;
use Test;
use Vikna::Utils;
use Vikna::X;

plan 12;

is to-style(VSUnderline), VSTransparent, "no VSBase results in transparent style";
is to-style(VSBase +| VSItalic), VSBase +| VSItalic, "non-transparent style when VSBase is used";
is to-style([VSUnderline]), VSBase +| VSUnderline, "passing an array of effects results in non-transparent style";
is to-style((VSUnderline,)), VSBase +| VSUnderline, "passing a list of effects results in non-transparent style";
is to-style('underline bold'), VSBase +| VSBold +| VSUnderline, "string represenation is parsed correctly";
is to-style(''), VSTransparent, "empty string represents transparent style";
is to-style(' '), VSBase, "single space is no style";
is to-style('!'), VSBase +| VSBold, "single character is translated into a style constant";
is to-style(3.chr), VSTransparent, "chars below code is below 0x20 results in transparent style";
is to-style(0x43.chr), VSTransparent, "chars with codes where VSBase bit is not set result in transparent styles";
is to-style(Int), VSTransparent, "type object results in transparent style";
fails-like
    { to-style("semi bold style") },
    X::CAttr::UnknownStyle,
    "bad style name causes expected failure",
    :message(q<Unknown style name 'semi'>),
    :style('semi');

done-testing;
