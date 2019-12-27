use v6.e.PREVIEW;
unit class Vikna::Widget;
use Vikna::Object;
use Vikna::Parent;
use Vikna::Child;
use Vikna::Belongable;
use Vikna::EventHandling;

also is Vikna::Object;
also does Vikna::Parent[::?CLASS];
also does Vikna::Child;
also does Vikna::Belongable[::?CLASS];
also does Vikna::EventHandling;

use Vikna::Rect;
use Vikna::Events;
use Vikna::X;
use Vikna::Color;
use Vikna::Canvas;
use Vikna::Utils;
use AttrX::Mooish;

has Vikna::Rect:D $.geom is required handles <x y w h>;
has $.bg-pattern;
has $.fg;
has $.bg;
has Bool:D $.auto-clear = False;
has Vikna::Canvas $.canvas is mooish(:lazy, :clearer, :predicate);
has Vikna::Canvas $!draw-canvas;
has $!draw-lock = Lock.new;

has @!invalidations;

multi method new(Int:D $x, Int:D $y, Dimension $w, Dimension $h, *%c) {
    self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
}

multi method new(Int:D :$x, Int:D :$y, Dimension :$w, Dimension :$h, *%c) {
    self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
}

method build-canvas {
    $.create: Vikna::Canvas, geom => $!geom.clone;
}

method create-child(Vikna::Widget:U $wtype, |c) {
    $.create: $wtype, :parent(self), :owner(self), |c;
}

proto method event(Event:D $ev) {
    {*}

    self.for-children: {
        .event($ev) unless $_ === $ev.dispatcher;
    }
    CONTROL {
        when CX::Event::Last {
            $.debug: "STOP EVENT HANDLING for ", $ev.^name;
        }
        default {
            .rethrow
        }
    }
}

multi method event(Event::RedrawRequest:D $ev) {
    self.redraw;
}

# Sink any unhandled event. Clear if we dispatched it.
multi method event(Event:D $ev) {
    $ev.clear if $ev.dispatcher === self
}

proto method child-event(Vikna::Event:D) {*}

multi method child-event(Event::Geomish:D $ev) {
    self.invalidate: $ev.from;
    self.invalidate: $ev.to;
    self.request-redraw;
}

multi method child-event(Event::RedrawRequest:D $ev) {
    $.dispatch: $ev
}

multi method child-event(Event::Detach:D $ev) {
    unless $ev.parent<> =:= self {
        # A bug protection: we must never receive a detach event where the parent is not us.
        self.throw: X::Event::ReParent, ev => $ev
    }
    self.unsubscribe($ev.dispatcher);
}

multi method child-event(Event:D) { }

method attach( :$parent ) {
    $.dispatch: Event::Attach, :$parent
}

method detach( :$parent ) {
    $.dispatch: Event::Detach, :$parent
}

method add-child(::?CLASS:D $child) {
    self.subscribe: $child, {
        self.child-event($_)
    };
    self.Vikna::Parent::add-child: $child;
}

method remove-child(::?CLASS:D $child) {
    self.unsubscribe: $child;
    self.Vikna::Parent::remove-child: $child;
}

method debug(*@args) {
    $.app.debug: "({self.WHICH}) ", |@args;
}

proto method invalidate(|) {*}

multi method invalidate(Vikna::Rect:D $rect) {
    $.for-children:
        {
            .invalidate: $rect.relative-to(.geom, :clip)
        },
        pre => {
            $.add-inv-rect: $rect
        }
}

multi method invalidate(::?CLASS:D $widget) {
    $.invalidate: $widget.geom.clone
}

multi method invalidate(UInt:D $x, UInt:D $y, Dimension $w, Dimension $h) {
    $.invalidate: $.create( Vikna::Rect, :$x, :$y, :$w, :$h )
}

multi method invalidate(UInt:D :$x, UInt:D :$y, Dimension :$w, Dimension :$h) {
    $.invalidate: $.create( Vikna::Rect, :$x, :$y, :$w, :$h )
}

multi method invalidate() {
    $.parent.invalidate: self
}

method clear {
    $.for-children: { .clear },
                    post => { self.clear-canvas };
    $.dispatch: Event::Clear;
}

method begin-draw(Vikna::Canvas $canvas? is copy --> Vikna::Canvas) {
    $!draw-lock.lock;
    LEAVE $!draw-lock.unlock;

    $canvas //= $.create:
                    Vikna::Canvas,
                    geom => $!geom.clone,
                    |($!auto-clear ?? () !! :from($!canvas));
    $.debug: "begin-draw canvas (auto-clear:{$!auto-clear}): ", $canvas.WHICH, " ", $canvas.w, " x ", $canvas.h;
    self.invalidate if $!auto-clear;
    $!draw-canvas = $canvas;

    for @!invalidations {
        $canvas.invalidate: $_
    }

    @!invalidations = [];

    $canvas
}

method end-draw( :$canvas! ) {
    $!draw-lock.lock;
    LEAVE $!draw-lock.unlock;

    $.debug: "end-draw canvas: ", $.canvas.WHICH;
    # Because more than one draw session might happen simultaneously,
    if cas($!draw-canvas, $canvas, Nil) === $canvas {
        $.debug: "end-draw setting new canvas";
        $!canvas = $canvas;
    }
}

method redraw {
    self.hold-events: Event::RedrawRequest, :kind(HoldLast), {
        my Vikna::Canvas:D $canvas = self.begin-draw;
        $.debug: "DRAWING, canvas has ", $canvas.invalidations.elems, " invalidations";
        self.draw( :$canvas );
        self.end-draw( :$canvas );
    }
}

method request-redraw {
    self.dispatch: Event::RedrawRequest;
    @!invalidations = [];
}

method draw(:$canvas) {
    self.draw-background(:$canvas);
}

method draw-background( :$canvas ) {
    if $!bg-pattern {
        $.debug: "Filling background with '{$!bg-pattern}'";
        my $back-row = ( $!bg-pattern x ($.w.Num / $!bg-pattern.chars).ceiling );
        for ^$.h -> $row {
            $canvas.imprint(0, $row, $back-row, :$!fg, :$!bg)
        }
    }
}

method compose(:$to = $!canvas) {
    # Compose children into our canvas
    self.for-children: {
        .compose;
        $to.imprint: .x, .y, .canvas;
    }
}

method resize(Dimension :$w = $.w, Dimension :$h = $.h) {
    $.debug: "? resizing to $w x $h";
    my $from;
    cas $!geom, {
        $from = $!geom;
        $!geom.clone: :$w, :$h
    };
    self.dispatch: Event::Resize, :$from, to => $!geom
        if $from.w != $!geom.w || $from.h != $!geom.h;
}

method move(:$x where * >= 0 = $.x, :$y where * >= 0 = $.y) {
    return if $x == $.x && $y == $.y;
    my $from;
    cas $!geom, {
        $from = $!geom;
        $!geom.clone: :$x, :$y;
    };
    self.dispatch: Event::Move, :$from, to => $!geom;
}

multi method set_color(BasicColor :$fg, BasicColor :$bg) {
    return if $!fg eq $fg && $!bg eq $bg;
    my ($old-fg, $old-bg);
    $old-fg = $!fg;
    $old-bg = $!bg;
    $!fg = $fg;
    $!bg = $bg;
    self.dispatch: Event::ColorChange, :$old-fg, :$old-bg, :$fg, :$bg if $old-fg ne $fg || $old-bg ne $bg;
}

method add-inv-rect(Vikna::Rect:D $rect) {
    @!invalidations.push: $rect;
}
