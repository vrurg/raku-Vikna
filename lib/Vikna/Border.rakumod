use v6.e.PREVIEW;

unit class Vikna::Border;

use Vikna::Widget::GroupMember;
use Vikna::Events;

also is Vikna::Widget::GroupMember;

my %borders =
        ascii => %(
            passive => %(
                :ul<+>, :t<->, :ur<+>,
                 :l<|>,         :r<|>,
                :bl<+>, :b<->, :br<+>,
                # Connectors
                :cl<+>, :cr<+>, :ct<+>, :cb<+>,
            ),
            active => %(
                :ul<+>, :t<=>, :ur<+>,
                 :l<|>,         :r<|>,
                :bl<+>, :b<->, :br<+>,
                # Connectors
                :cl<+>, :cr<+>, :ct<+>, :cb<+>,
            ),
        ),
        ;
has $.type = 'ascii';

### Event handlers

# Set own 'event horizon'
proto method event(Event:D $) {*}

multi method event(Event::Attached:D $ev) {
    if $ev.child === self {
        $.subscribe: $.parent, -> $pev {
            if $pev ~~ Event::Focus::In | Event::Focus::Out {
                $.trace: "Parent focus in/out event, redraw self";
                $.invalidate;
                $.redraw;
            }
        }
    }
    nextsame
}

multi method event(Event:D $) { nextsame }

### Command senders ###

# Prevent voluntary geom changes
method set-geom(|) { }

### Utility methods ###

method draw( :$canvas ) {
    my %b = %borders{ $!type }{ $.group.in-focus ?? 'active' !! 'passive' };
    $.trace: "### BORDER DRAW, group focused: ", ?$.group.in-focus;
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
    if $.parent.?title && $.w > 6 {
        my $title = " " ~ $.parent.title.substr(0, $.w - 6) ~ " ";
        $.trace: "Using title ‘$title’";
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
