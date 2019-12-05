use v6;
use Term::UI::Widget;
unit class Term::UI::Window::Border is Term::UI::Widget;

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

method draw( :$grid ) {
    my %b = %borders{ $!type };
    my $r = $.w - 1;
    my $b = $.h - 1;
    $grid.change-cell(0,   0, %b<ul>);
    $grid.change-cell($r,  0, %b<ur>);
    $grid.change-cell(0,  $b, %b<bl>);
    $grid.change-cell($r, $b, %b<br>);
    my $bottom = %b<b> x ($.w - 2);
    $grid.set-span-text(1, $b, $bottom);
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
    $grid.set-span-text(1, 0, $top);
    for 1..($.h-2) -> $y {
        $grid.change-cell(0,  $y, %b<l>);
        $grid.change-cell($r, $y, %b<r>);
    }
}
