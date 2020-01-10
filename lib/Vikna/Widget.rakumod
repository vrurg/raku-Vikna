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
# also does Vikna::Belongable[::?CLASS];
also does Vikna::EventHandling;

use Vikna::Rect;
use Vikna::Events;
use Vikna::X;
use Vikna::Color;
use Vikna::Canvas;
use Vikna::Utils;
use AttrX::Mooish;

my class CanvasReqRecord {
    has @.invalidations;
    has Vikna::Rect:D $.geom is required;
    has Vikna::Canvas:D $.canvas is required;
}

has Vikna::Rect:D $.geom is required handles <x y w h>;
has $.bg-pattern;
has $.fg;
has $.bg;
has Bool:D $.auto-clear = False;
has Vikna::Canvas $.canvas is mooish(:lazy, :clearer, :predicate);
has $!draw-lock = Lock::Async.new;
# Widget's geom at the moment when canvas has been drawn.
has Vikna::Rect $!canvas-geom;

has Event $!redraw-on-hold;
has Semaphore:D $!redraws .= new(1);

has @.invalidations;
# Invalidations mapped into parent's coords. To be pulled out together with widget canvas for imprinting into parent's
# canvas.
has $!stash-parent-invs = []; # Invalidations for parent widget are to be stashed here first ...
has $!inv-for-parent = [];    # ... and then added here when redraw finalizes

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
    # $.create: $wtype, :parent(self), :owner(self), |c;
    my $child = $.create: $wtype, :parent(self), |c;
    self.Vikna::Parent::add-child: $child;
    self.subscribe-to-child: $child;
    $child
}

method subscribe-to-child(Vikna::Widget:D $child) {
    self.subscribe: $child, -> $ev {
        # Redispatch only informative events as all we may need is to be posted about child changes.
        self.child-event($ev) if $ev ~~ Event::Informative
    };
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
        $ev.completed.keep( self."$cmd-name"( |$ev.args ) );
        $.debug: "COMPLETED COMMAND EVENT: ", $cmd-name;
    }
    elsif self.^can('CMD-FALLBACK') {
        $.debug: "PASSING TO CMD-FALLBACK";
        $ev.completed.keep( self.CMD-FALLBACK($ev) );
        $.debug: "COMPLETED COMMAND FALLBACK";
    }
    nextsame
}

# Sink any unhandled event. Clear if we dispatched it (this is what makes it different from EventHandling sinker).
multi method event(Event:D $ev) {
    $ev.clear if $ev.dispatcher === self
}

proto method child-event(Event:D) {*}

multi method child-event(Event:D) { }

### Command handlers ###

method cmd-addchild(Vikna::Widget:D $child) {
    self.Vikna::Parent::add-child: $child;
    self.subscribe-to-child($child);
    self.dispatch: Event::Attached, :$child, :parent(self);
}

method cmd-removechild(Vikna::Widget:D $child) {
    self.unsubscribe: $child;
    self.Vikna::Parent::remove-child: $child;
    self.dispatch: Event::Detached, :$child, :parent(self)
}

method cmd-clear() {
    $.for-children: { .clear },
                    post => { self.clear-canvas };
    self.redraw;
}

method cmd-close() {
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
    self.stop-event-handling;
}

method cmd-redraw(Promise:D $redrawn) {
    my Vikna::Canvas:D $canvas = $!canvas;
    my @cpromises;
    my @chld-canvas;
    $.debug: "REQ CHIDLREN CANVAS";
    $.for-children: -> $chld {
        $.debug: "REQ FROM CHILD ", $chld.WHICH;
        @cpromises.push: $chld.send-command( Event::Cmd::CanvasReq ).response;
    };
    $.debug: "AWATING FOR CHILDREN RESPONSE";
    await Promise.allof(@cpromises) if @cpromises;
    $.debug: "DONE AWATING FOR CHILDREN RESPONSE";
    @chld-canvas = eager @cpromises.grep( { .status ~~ Kept } ).map: *.result;
    $.invalidate: .invalidations for @chld-canvas;
    $.debug: "CMD REDRAW: invalidations: ", @!invalidations.elems, " // ", @!invalidations.map( *.Str ).join(" | ");
    if @!invalidations {
        $.debug: "BEGIN DRAW";
        $canvas = self.begin-draw;
        self.draw( :$canvas );
        self.end-draw( :$canvas );
        $.debug: "END DRAW";
        for @chld-canvas {
            $.debug: " ... applying child canvas at {.geom.x},{.geom.y}";
            $canvas.imprint: .geom.x, .geom.y, .canvas;
        }
        # We've done drawing itself, wait for children to complete.
        $.debug: "ALL CHILDREN CANVAS IMPRINTED";
        $!canvas = $canvas;
        .redraw with $.parent;
    }
    LEAVE {
        $.debug: "REDRAWN";
        $redrawn.keep($.geom.clone);
    }
}

method cmd-canvasreq(Promise:D $response) {
    if $!canvas-geom {
        my @invalidations;
        $.debug: "CANVAS REQ COMMAND";
        cas $!inv-for-parent, {
            @invalidations = $_;
            []
        };
        $.debug: "CANVAS REQ: KEEPING THE RESPONSE";
        $response.keep( CanvasReqRecord.new: :@invalidations, :$!canvas, geom => $!canvas-geom );
        $.debug: "CANVAS REQ: KEPT THE RESPONSE";
    }
    else {
        $response.break( Nil )
    }
}

method cmd-setgeom(Vikna::Rect:D $geom) {
    $.debug: "? changing geom to ", $geom;
    my $from;
    cas $!geom, {
        $from = $_;
        $geom.clone
    };
    $.debug: "? setgeom invalidations";
    $.add-inv-parent-rect: $from;
    $.add-inv-parent-rect: $geom;
    $.invalidate;
    $.debug: "? setgeom redraw";
    $.redraw;
    $.debug: "? setgeom notify";
    self.dispatch: Event::GeomChanged, :$from, to => $!geom
        if    $from.x != $!geom.x || $from.y != $!geom.y
           || $from.w != $!geom.w || $from.h != $!geom.h;
}

method cmd-setcolor(BasicColor :$fg, BasicColor :$bg) {
    return if $!fg eq $fg && $!bg eq $bg;
    my ($old-fg, $old-bg);
    $old-fg = $!fg;
    $old-bg = $!bg;
    $!fg = $fg;
    $!bg = $bg;
    self.dispatch: Event::WidgetColor, :$old-fg, :$old-bg, :$fg, :$bg if $old-fg ne $fg || $old-bg ne $bg;
}

method cmd-nop() { }

### Command senders ###
proto method setnd-command(|) {
    {*}
}
multi method send-command(Event::Command \evType, |args) {
    CATCH {
        when X::Event::Stopped {
            .ev.completed.break($_);
            return .ev
        }
        default {
            .rethrow;
        }
    }
    self.dispatch: evType, :args(args);
}

method add-child(::?CLASS:D $child) {
    self.send-command: Event::Cmd::AddChild, $child;
}

method remove-child(::?CLASS:D $child) {
    self.send-command: Event::Cmd::RemoveChild, $child;
}

method redraw {
    self.send-command: Event::Cmd::Redraw;
}

method clear {
    self.send-command: Event::Cmd::Clear;
}

method close {
    self.send-command: Event::Cmd::Close;
}

method resize(Dimension:D $w, Dimension:D $h) {
    self.send-command: Event::Cmd::SetGeom, $!geom.clone( :$w, :$h );
}

method move(Int:D $x, Int:D $y) {
    self.send-command: Event::Cmd::SetGeom, $!geom.clone( :$x, :$y );
}

multi method set-geom(Int:D $x, Int:D $y, Dimension:D $w, Dimension:D $h) {
    self.send-command: Event::Cmd::SetGeom, Vikna::Rect.new(:$x, :$y, :$w, :$h)
}

method set-color(BasicColor :$fg, BasicColor :$bg) {
    self.send-command: Event::Cmd::SetColor, :$fg, :$bg
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
    $.send-command: Event::Cmd::Nop
}

### Utility methods ###

method add-inv-parent-rect(Vikna::Rect:D $rect) {
    if $.parent {
        $.debug: "ADD TO STASH OF PARENT INVS: ", ~$rect;
        cas $!stash-parent-invs, {
            .push: $rect;
            $_
        }
    }
}

method add-inv-rect(Vikna::Rect:D $rect) {
    @!invalidations.push: $rect;
    $.add-inv-parent-rect: $rect.absolute($!geom);
}

method clear-invalidations {
    @!invalidations = [];
}

proto method invalidate(|) {*}

multi method invalidate(Vikna::Rect:D $rect) {
    $.debug: "INVALIDATE ", ~$rect, " -> ", $.parent.WHICH, " as ", $rect.absolute($.geom);
    $.add-inv-rect: $rect;
}

multi method invalidate(UInt:D $x, UInt:D $y, Dimension $w, Dimension $h) {
    $.invalidate: Vikna::Rect.new( :$x, :$y, :$w, :$h )
}

multi method invalidate(UInt:D :$x, UInt:D :$y, Dimension :$w, Dimension :$h) {
    $.invalidate: Vikna::Rect.new( :$x, :$y, :$w, :$h )
}

multi method invalidate() {
    $.invalidate: Vikna::Rect.new( :0x, :0y, :$.w, :$.h )
}

multi method invalidate(@invalidations) {
    $.invalidate: $_ for @invalidations
}

method begin-draw(Vikna::Canvas $canvas? is copy --> Vikna::Canvas) {
    $!canvas-geom = $!geom.clone;
    $canvas //= $.create:
                    Vikna::Canvas,
                    geom => $!geom.clone,
                    # :inv-mark-color('blue'),
                    |($!auto-clear ?? () !! :from($!canvas));
    $.invalidate if $!auto-clear;
    $.debug: "begin-draw canvas (auto-clear:{$!auto-clear}): ", $canvas.WHICH, " ", $canvas.w, " x ", $canvas.h;

    for @!invalidations {
        $canvas.invalidate: $_
    }

    $canvas
}

method end-draw( :$canvas! ) {
    $.draw-protect: {
        $!inv-for-parent.append: @$!stash-parent-invs;
        $!stash-parent-invs = [];
    }
    self.clear-invalidations;
    $.dispatch: Event::Updated, geom => $!canvas-geom;
}

method draw-protect(&code) is raw {
    $!draw-lock.lock;
    LEAVE {
        $!draw-lock.unlock;
    }
    &code()
}

method draw(:$canvas) {
    self.draw-background(:$canvas);
}

method draw-background( :$canvas ) {
    if $!bg-pattern {
        my $back-row = ( $!bg-pattern x ($.w.Num / $!bg-pattern.chars).ceiling );
        for ^$.h -> $row {
            $canvas.imprint(0, $row, $back-row, :$!fg, :$!bg)
        }
    }
}

# Filters are protected from concurrency by EventHandling
multi method event-filter(Event::Cmd::Redraw:D $ev) {
    $.debug: "WIDGET EV FILTER: ", $ev.^name;
    if $!redraws.try_acquire {
        # There is no current redraws, we just proceed further but first make sure we release the resource when done.
        $ev.redrawn.then: {
            $.debug: "RELEASING REDRAW SEMAPHORE, held redraw event: ", $!redraw-on-hold.WHICH;
            my $rh;
            cas $!redraw-on-hold, {
                # If there is a redraw event pending then release it into the wild.
                # self.debug: "RELEASE HELD EVENT with invs: ", $rh.invalidations.elems;
                $rh = $_;
                Nil
            };
            $!redraws.release;
            self.send-event: $rh if $rh;
            $.debug: "REDRAW RELEASE DONE";
        };
        [$ev]
    }
    else {
        # There is another redraw active.
        $.debug: "PUT ", $ev.WHICH, " on hold";
        cas $!redraw-on-hold, {
            if $_ {
                $ev.redrawn.keep(True);
                $_
            }
            else {
                $ev
            }
        }
        # This event won't go any further...
        []
    }
}
