use v6.e.PREVIEW;
use Vikna::Widget;
use Vikna::Border;
unit class Vikna::Window is Vikna::Widget is export;

use Vikna::Events;
use Vikna::Utils;

class Client is Vikna::Widget {
    method fit {
        my ($w, $h) = $.owner.client-size;
        self.Vikna::Widget::resize(:$w, :$h)
    }
    # Don't allow voluntary client size change.
    method resize { }
}

has Str:D $.title = "";
has $.border;
has Client $.client handles <add-child remove-child create-child to-top to-bottom for-children children-protect>;

has $!win-lock = Lock.new;

submethod TWEAK(Bool:D :$border = True) {
    my ($cx, $cy, $cw, $ch) = (0, 0, self.w, self.h);
    if $border {
        $!border = Vikna::Border.new:
                        :w( $cw ), :h( $ch ), :x(0), :y(0),
                        :app( self.app ),
                        :owner( self ),
                        :!auto-clear;
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    $!client = Client.new:
                    :x( $cx ), :y( $cy ), :w( $cw ), :h( $ch ),
                    :app( self.app ),
                    :owner( self ),
                    :bg-pattern('.-+'),
                    :color<black blue>,
                    :auto-clear( self.auto-clear );
}

method for-elems(&code) {
    $!win-lock.protect: {
        for $!border, $!client -> $elem {
            &code($elem)
        }
    }
}

method set-title(Str:D $title) {
    my $old-title = $!title;
    $!title = $title;
    self.dispatch: Event::TitleChange, :$old-title, :$title
}

method clear {
    $!client.clear;
}

# method redraw {
#     $.hold-events: Event::RedrawRequest, :kind(HoldFirst), {
#         my $canvas = self.begin-draw;
#         self.draw( :$canvas );
#         self.end-draw( :$canvas );
#     }
# }

method redraw {
    $.debug: "WINDOW REDRAW METHOD";
    nextsame;
}

method draw(:$canvas) {
    $.debug: "WINDOW DRAWING"; #, invalidations: ", $canvas.invalidations.elems;
    nextsame;
}

multi method invalidate(Vikna::Rect:D $rect) {
    $.add-inv-rect: $rect;
    $.for-elems: {
        .invalidate: $rect.relative-to(.geom, :clip)
    };
}

method client-size {
    my $bw = $!border ?? 2 !! 0;
    ($.w - $bw, $.h - $bw)
}

method resize(Int:D :$w is copy where * > 0 = $.w, Int:D :$h is copy where * > 0 = $.h) {
    my $min = $!border ?? 4 !! 2;
    $w max= $min;
    $h max= $min;
    nextwith(:$w, :$h)
}

method compose(:$to = $.canvas) {
    $.debug: "INVALIDATES ON CANVAS: ", $to.invalidations.elems;
    $.for-elems: {
        .compose;
        $.debug: "IMPRINT ", $_.WHICH, " into ", .x, ", ", .y;
        $to.imprint: .x, .y, .canvas;
    }
    # $.app.screen.print: 0,0, $to;
}

multi method event(Event::TitleChange:D) {
    self.dispatch: Event::RedrawRequest;
}

multi method event(Event::Resize:D $ev) {
    $!win-lock.protect: {
        $!client.fit;
        $!client.resize(:w($.w - 2), :h($.h - 2));
        $!border.resize(:$.w, :$.h);
    }
    self.dispatch: Event::RedrawRequest;
}

multi method event(Event::RedrawRequest:D $ev) {
    $.for-elems: {
        .dispatch: $ev
    }
    nextsame;
}
