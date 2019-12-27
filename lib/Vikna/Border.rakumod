use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Border is Vikna::Widget;

my %borders =
        ansi => %(
            :ul<+>, :t<->, :ur<+>,
             :l<|>,         :r<|>,
            :bl<+>, :b<->, :br<+>,
            # Connectors
            :cl<+>, :cr<+>, :ct<+>, :cb<+>,
        ),
        ;
has $.type = 'ansi';

method draw( :$canvas ) {
    $.debug: "### BORDER DRAW, invalidations: ", $canvas.invalidations.elems;
    my %b = %borders{ $!type };
    my $r = $.w - 1;
    my $b = $.h - 1;
    $canvas.imprint(0,   0, %b<ul>);
    $canvas.imprint($r,  0, %b<ur>);
    $canvas.imprint(0,  $b, %b<bl>);
    $canvas.imprint($r, $b, %b<br>);
    my $bottom = %b<b> x ($.w - 2);
    $canvas.imprint(1, $b, $bottom);
    # Limit title length.
    my $top;
    if $.owner.?title && $.w > 6 {
        my $title = " " ~ $.owner.title.substr(0, $.w - 6) ~ " ";
        my $tlen = $.w - 2 - $title.chars;
        my $l-len = $tlen div 2;
        my $r-len = $tlen - $l-len;
        $top = (%b<t> x $l-len) ~ $title ~ (%b<t> x $r-len);
    }
    else {
        $top = %b<t> x $.w - 2;
    }
    $canvas.imprint(1, 0, $top);
    for 1..($.h-2) -> $y {
        $canvas.imprint(0,  $y, %b<l>);
        $canvas.imprint($r, $y, %b<r>);
    }
}
