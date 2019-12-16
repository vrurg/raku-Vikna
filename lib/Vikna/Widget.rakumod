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

# A lock prevents the widget from redrawing
has atomicint $!locks = 0;

multi method new(Int:D $x, Int:D $y, Dimension $w, Dimension $h, *%c) {
    self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
}

multi method new(Int:D :$x, Int:D :$y, Dimension :$w, Dimension :$h, *%c) {
    self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
}

submethod TWEAK(|c) {
    # .add-child(self) with $!parent;
    self.events.subscribe: -> $ev { self.event: $ev }
}

method build-canvas {
    $.create: Vikna::Canvas, geom => $!geom.clone;
}

method create-child(Vikna::Widget:U $wtype, |c) {
    $.create: $wtype, :parent(self), :owner(self), |c;
}

proto method event(Event:D $ev) {
    {*}

    unless $ev.clear {
        .event($ev) for @.children;
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

multi method child-event(Event::Geom:D $ev) {
    $.draw-protect: {
        self.invalidate: $ev.from;
        self.invalidate: $ev.to;
    }
    $.dispatch: Event::RedrawRequest;
}

multi method child-event(Event::RedrawRequest:D $ev) {
    $.dispatch: $ev
}

multi method child-event(Event:D) { }

method attach( :$parent ) {
    $.dispatch: Event::Attach, :$parent
}

method detach( :$parent ) {
    $.dispatch: Event::Detach, :$parent
}

method setup-child-monitor(::?CLASS:D $SELF: ::?CLASS:D $child ) {
    start react {
        whenever $child.events {
            when Event::Detach {
                unless .parent<> =:= $SELF<> {
                    # A bug protection: we must never receive a detach event where the parent is not us.
                    $SELF.throw: X::Event::ReParent, ev => $_
                }
                # Let our subclasses take actions if need to...
                $SELF.child-event: $_;
                # ... and stop processing events from this child.
                done;
            }
            default {
                $SELF.child-event($_)
            }
        }
    }
}

method add-child(::?CLASS:D $child) {
    self.setup-child-monitor($child);
    self.Vikna::Parent::add-child($child);
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
            @!invalidations.push: $rect
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
    return Nil if $.locked;

    $!draw-lock.lock;
    LEAVE $!draw-lock.unlock;

    $canvas //= $!auto-clear || $.w != $!canvas.w || $.h != $!canvas.h
                ?? $.create: Vikna::Canvas, geom => $!geom.clone,
                    |($!auto-clear ?? () !! :from-cells($!canvas.cells))
                !! $!canvas; # <-- XXX potentially problematic.
    $.debug: "begin-draw canvas: ", $canvas.WHICH, " ", $canvas.w, " x ", $canvas.h;
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

    $.debug: "end-draw   canvas: ", $.canvas.WHICH;
    # Because more than one draw session might happen simultaneously,
    if $canvas === $!draw-canvas {
        $.debug: "end-draw setting new canvas";
        $!canvas = $canvas;
        $!draw-canvas = Nil;
    }
}

method redraw {
    return if $.locked;
    my Vikna::Canvas:D $canvas = self.begin-draw;
    my $abort-draw = False;
    for @.children {
        # Stop if another thread started drawing.
        last if $abort-draw = !($canvas === $!draw-canvas);
        .redraw;
    }
    self.draw-background( :$canvas );
    unless $abort-draw {
        self.?draw( :$canvas );
    }
    self.debug: "Aborted draw? ", $abort-draw;
    self.end-draw( :$canvas );
}

method draw-background( :$canvas ) {
    if $!bg-pattern {
        my $back-row = ( $!bg-pattern x ($.w.Num / $!bg-pattern.chars).ceiling );
        for ^$.h -> $row {
            $canvas.imprint(0, $row, $back-row, :$!fg, :$!bg)
        }
    }
}

method compose {
    # Compose children into our canvas
    self.for-children: {
        .compose;
        $!canvas.imprint: .x, .y, .canvas;
    }
}

method resize(Dimension :$w = $.w, Dimension :$h = $.h) {
    $.draw-protect: {
        $.debug: "? resizing to $w x $h";
        my $old-w = $.w;
        my $old-h = $.h;
        cas $!geom, { $!geom.clone: :$w, :$h };
        self.dispatch: Event::Resize, :$old-w, :$old-h, :$w, :$h
            if $old-w != $w || $old-h != $h;
    }
}

method move(:$x where * >= 0 = $.x, :$y where * >= 0 = $.y) {
    return if $x == $.x && $y == $.y;
    my $old;
    cas $!geom, {
        $old = $!geom;
        $!geom.move($x, $y);
    };
    self.dispatch: Event::Move, :$old, new => $!geom;
}

multi method set_color(BasicColor :$fg, BasicColor :$bg) {
    return if $!fg eq $fg && $!bg eq $bg;
    my ($old-fg, $old-bg);
    $.draw-protect: {
        $old-fg = $!fg;
        $old-bg = $!bg;
        $!fg = $fg;
        $!bg = $bg;
    }
    self.dispatch: Event::ColorChange, :$old-fg, :$old-bg, :$fg, :$bg if $old-fg ne $fg || $old-bg ne $bg;
}

method lock {
    $!locks⚛++;
    self.for-children: { .lock };
}

method unlock() {
    if --⚛$!locks < 0 {
        self.throw: X::Widget::ExtraUnlock, :count(-⚛$!locks);
    }
    self.for-children: { .unlock }
}

method locked {
    $!locks > 0;
}

method draw-protect(&code) {
    $.lock;
    LEAVE $.unlock;
    &code()
}
