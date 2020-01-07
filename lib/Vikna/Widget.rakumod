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
has $!draw-lock = Lock::Async.new;

has @.invalidations;

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

method debug(*@args) {
    $.app.debug: |@args, obj => self;
}

proto method event(Event:D $ev) {
    {*}

    # Commands are not to be re-dispatched to children. If any changes in children are required they're to be initiated
    # via their respective methods.
    unless $ev ~~ Event::Command {
        self.for-children: {
            .event($ev) unless $_ === $ev.dispatcher | $ev.origin;
        }
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

# Event::Command is a role and would be more generic than any particular event class.
multi method event(Event::Command:D $ev) {
    # To form a default command name everything up to and including Event in event's class FQN is stripped off. The
    # remaining elements are lowercased and joined with a dash:
    # Vikna::Event::Cmd::Name -> cmd-name
    # Vikna::TextScroll::Event::SomeCmd::Name -> somecmd-name
    my $cmd-name = $ev.^can("cmd")
                    ?? $ev.cmd
                    !! $ev.^name
                          .split( '::' )
                          .grep({ "Event" ^ff * })
                          .map( *.lc )
                          .join( '-' );
    $.debug: "COMMAND EVENT: ", $cmd-name;
    if self.^can($cmd-name) {
        $ev.completed.keep( self."$cmd-name"($ev) );
        $.debug: "COMPLETED COMMAND EVENT: ", $cmd-name;
    }
    nextsame
}

# Sink any unhandled event. Clear if we dispatched it (this what makes it different from EventHandling sinker).
multi method event(Event:D $ev) {
    $ev.clear if $ev.dispatcher === self
}

proto method child-event(Event:D) {*}

multi method child-event(Event::GeomChange:D $ev) {
    self.invalidate: $ev.from;
    self.invalidate: $ev.to;
    self.redraw;
}

multi method child-event(Event::Updated:D $ev) {
    # When a child is updated behave as it's our update. Just remap invalidations into our coordinates.
    self.updated: $ev.invalidations.map( *.absolute($ev.geom) );
}

multi method child-event(Event:D) { }

### Command handlers ###

method cmd-addchild(Event::Cmd::AddChild:D $ev) {
    my $child = $ev.child;
    self.Vikna::Parent::add-child: $child;
    self.subscribe: $child, {
        # Redispatch only informative events as all we may need is to be posted about child changes.
        self.child-event($_) if $_ ~~ Event::Informative
    };
    self.dispatch: Event::Attached, :$child, :parent(self);
}

method cmd-removechild(Event::Cmd::RemoveChild:D $ev) {
    my $child = $ev.child;
    self.unsubscribe: $child;
    self.Vikna::Parent::remove-child: $child;
    self.dispatch: Event::Detached, :$child, :parent(self)
}

method cmd-clear(Event::Cmd::Clear:D $ev) {
    $.for-children: { .clear },
                    post => { self.clear-canvas };
    self.redraw;
}

method cmd-close(Event::Cmd::Close:D $ev) {
    my @completions;
    $.debug: "CLOSING";
    $.debug: "REMOVING SELF FROM PARENT";
    .remove-child(self) with $.parent;

    $.for-children: {
        @completions.push: .close.completed
    }
    $.debug: "AWAITING CHILDREN TO CLOSE";
    await Promise.allof(@completions);
    $.debug: "FINISHING SELF";
    self.?finish;
    self.shutdown-events;
}

method cmd-redraw(Event::Cmd::Redraw:D $ev) {
    my @invalidations = $ev.invalidations;
    my Vikna::Canvas:D $canvas = $!canvas;
    $.debug: "CMD REDRAW: invalidations: ", $ev.invalidations.elems;
    if @invalidations {
        $canvas = self.begin-draw: invalidations => $ev.invalidations;
        my @cpromises;
        $.debug: "REDRAW CHIDLREN";
        $.for-children: -> $chld {
            $.debug: "REDRAW CHILD ", $chld.WHICH;
            my @invalidations = $ev.invalidations
                                    .map( *.relative-to: $chld.geom, :clip )
                                    .grep( { $chld.w & $chld.h > 0 } );
            @cpromises.push: $chld.dispatch( Event::Cmd::Redraw, :@invalidations ).redrawn;
        },
        post => {
            $.debug: "POST-CHILDREN, DO DRAW";
            self.draw( :$canvas );
            self.end-draw( :$canvas );
        };
        # We've done drawing itself, wait for children to complete.
        $.debug: "Awaiting for children to complete";
        await Promise.allof(@cpromises) if @cpromises;
        $.debug: "ALL CHILDREN REDRAWN";
        for @cpromises.map(*.result) -> [$cgeom, $ccanvas] {
            $canvas.imprint: $cgeom.x, $cgeom.y, $ccanvas;
        }
        $!canvas = $canvas;
    }
    LEAVE with $ev.redrawn {
        $.debug: "REDRAWN";
        .keep([$.geom.clone, $canvas])
    }
}

method cmd-setgeom(Event::Cmd::SetGeom:D $ev) {
    $.debug: "? changing geom to ", $ev.geom;
    my $from;
    cas $!geom, {
        $from = $!geom;
        $ev.geom.clone
    };
    self.dispatch: Event::Geom, :$from, to => $!geom
        if    $from.x != $!geom.x || $from.y != $!geom.y
           || $from.w != $!geom.w || $from.h != $!geom.h;
}

method cmd-setcolor(Event::Cmd::SetColor:D $ev) {
    my $fg = $ev.fg;
    my $bg = $ev.bg;
    return if $!fg eq $fg && $!bg eq $bg;
    my ($old-fg, $old-bg);
    $old-fg = $!fg;
    $old-bg = $!bg;
    $!fg = $fg;
    $!bg = $bg;
    $ev.clear;
    self.dispatch: Event::WidgetColor, :$old-fg, :$old-bg, :$fg, :$bg if $old-fg ne $fg || $old-bg ne $bg;
}

method cmd-nop(Event::Cmd::Nop:D $ev) { }

### Command senders ###
method add-child(::?CLASS:D $child) {
    self.dispatch: Event::Cmd::AddChild, :$child;
}

method remove-child(::?CLASS:D $child) {
    self.dispatch: Event::Cmd::RemoveChild, :$child;
}

method redraw { $.parent.redraw }

method clear {
    self.dispatch: Event::Cmd::Clear;
}

method close {
    self.dispatch: Event::Cmd::Close;
}

method resize(Dimension:D $w, Dimension:D $h) {
    self.dispatch: Event::Cmd::SetGeom, geom => $!geom.clone: :$w, :$h;
}

method move(Int:D $x, Int:D $y) {
    self.dispatch: Event::Cmd::SetGeom, geom => $!geom.clone: :$x, :$y;
}

multi method set_geom(Int:D $x, Int:D $y, Dimension:D $w, Dimension:D $h) {
    self.dispatch: Event::Cmd::SetGeom, geom => Vikna::Rect.new(:$x, :$y, :$w, :$h)
}

method set_color(BasicColor :$fg, BasicColor :$bg) {
    self.dispatch: Event::Cmd::SetColor, :$fg, :$bg
}

method sync-events(:$transitive) {
    my @p;
    $.for-children: {
        @p.push: .nop.completed(:transitive);
    }
    @p.push: $.nop.completed;
    await @p;
}

method nop {
    $.dispatch: Event::Cmd::Nop
}

### Utility methods ###

method add-inv-rect(Vikna::Rect:D $rect) {
    @!invalidations.push: $rect;
}

method clear-invalidations {
    @!invalidations = [];
}

proto method invalidate(|) {*}

multi method invalidate(Vikna::Rect:D $rect) {
    $.parent.invalidate: $rect.absolute($.geom);
    # $.for-children:
    #     {
    #         .invalidate: $rect.relative-to(.geom, :clip)
    #     },
    #     pre => {
    #         $.add-inv-rect: $rect
    #     }
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
    $.invalidate: $.create( Vikna::Rect, :0x, :0y, :$.w, :$.h )
}

method begin-draw(Vikna::Canvas $canvas? is copy, :@invalidations --> Vikna::Canvas) {
    $.debug: "> begin-draw";
    $!draw-lock.lock;
    LEAVE {
        $!draw-lock.unlock;
        $.debug: "< begin-draw";
    }

    $canvas //= $.create:
                    Vikna::Canvas,
                    geom => $!geom.clone,
                    # :inv-mark-color('blue'),
                    |($!auto-clear ?? () !! :from($!canvas));
    $.debug: "begin-draw canvas (auto-clear:{$!auto-clear}): ", $canvas.WHICH, " ", $canvas.w, " x ", $canvas.h;
    $!draw-canvas = $canvas;

    for @invalidations {
        $canvas.invalidate: $_
    }

    $canvas
}

method end-draw( :$canvas! ) {
    $.debug: "> end-draw";
    $!draw-lock.lock;
    LEAVE {
        $!draw-lock.unlock;
        $.debug: "< end-draw";
    }

    $.debug: "end-draw canvas: ", $.canvas.WHICH;
    # Because more than one draw session might happen simultaneously,
    if cas($!draw-canvas, $canvas, Nil) === $canvas {
        $.debug: "end-draw setting new canvas";
        $!canvas = $canvas;
    }
}

method draw-protect(&code) is raw {
    $.debug: "> draw-protect";
    $!draw-lock.lock;
    LEAVE {
        $!draw-lock.unlock;
        $.debug: "< draw-protect";
    }
    &code()
}

method draw(:$canvas) {
    $.debug: "WIDGET DRAW -> DO BACKGROUND";
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

# Send Event::Updated with correct invalidations
method updated(:@invalidations, Vikna::Canvas:D :$canvas) {
    # While it's ok for redraw to have out of bound invalidation rects, Event::Updated must have  them clipped because
    # it reports where actual changes took place visibly.
    my @clipped-invs = @invalidations
                            .map( *.clip(0, 0, $.w, $.h) )
                            .grep( { .w > 0 && .h > 0 } ); # Throw away any invalidation if it's out of bounds
    # Don't dispatch the event if no visible changes were made.
    self.dispatch: Event::Updated, :invalidations(@clipped-invs), :$canvas, :$!geom if @clipped-invs;
}
