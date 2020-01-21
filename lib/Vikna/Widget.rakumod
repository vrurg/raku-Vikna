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
# Is widget invisible on purpose?
has Bool:D $.hidden = False;
# Is widget visible within its parent?
has Bool:D $.invisible = False;
has Vikna::Canvas $.canvas is mooish(:lazy, :clearer, :predicate);
# Widget's geom at the moment when canvas has been drawn.
has Vikna::Rect $!canvas-geom;

has Event $!redraw-on-hold;
has Semaphore:D $!redraws .= new(1);
has atomicint $!redraw-blocks = 0;

has @.invalidations;
# Invalidations mapped into parent's coords. To be pulled out together with widget canvas for imprinting into parent's
# canvas.
has $!stash-parent-invs = []; # Invalidations for parent widget are to be stashed here first ...
has $!inv-for-parent = [];    # ... and then added here when redraw finalizes

has $.inv-mark-color is rw; # For test purposes only.

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
    $.trace: "CREATING A CHILD OF ", $wtype.^name;
    my $child = $.create: $wtype, :parent(self), |c;
    self.add-child: $child;
    $child
}

method subscribe-to-child(Vikna::Widget:D $child) {
    self.subscribe: $child, -> $ev {
        # Redispatch only informative events as all we may need is to be posted about child changes.
        self.child-event($ev) if $ev ~~ Event::Informative
    };
}

proto method event(::?CLASS:D: Event:D $ev) {
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
            $.trace: "STOP EVENT HANDLING for ", $ev.^name;
        }
        default {
            .rethrow
        }
    }
}

multi method event(::?CLASS:D: Event::Command:D $ev) {
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
    $.trace: "COMMAND EVENT: ", $cmd-name;
    if self.^can($cmd-name) {
        $ev.completed.keep( self."$cmd-name"( |$ev.args ) );
        $.trace: "COMPLETED COMMAND EVENT: ", $cmd-name;
    }
    elsif self.^can('CMD-FALLBACK') {
        $.trace: "PASSING TO CMD-FALLBACK";
        $ev.completed.keep( self.CMD-FALLBACK($ev) );
        $.trace: "COMPLETED COMMAND FALLBACK";
    }
    nextsame
}

# Sink any unhandled event. Clear if we dispatched it (this is what makes it different from EventHandling sinker).
multi method event(::?CLASS:D: Event:D $ev) {
    $ev.clear if $ev.dispatcher === self
}

multi method event(::?CLASS:D: Event::Attached:D $ev) {
    if self === $ev.child {
        $.invalidate;
        $.redraw;
    }
}

proto method child-event(::?CLASS:D: Event:D) {*}

multi method child-event(::?CLASS:D: Event::Updated:D $ev) {
    $.trace: "CHILD ", $ev.origin.WHICH, " updated";
    $.redraw;
}

multi method child-event(::?CLASS:D: Event:D) { }

### Command handlers ###

method cmd-addchild(::?CLASS:D: Vikna::Widget:D $child) {
    $.trace: "ADDING CHILD ", $child.WHICH;
    self.Vikna::Parent::add-child: $child;
    self.subscribe-to-child($child);
    $child.invalidate;
    $child.redraw;
    self.dispatch: Event::Attached, :$child, :parent(self);
}

method cmd-removechild(::?CLASS:D: Vikna::Widget:D $child) {
    self.unsubscribe: $child;
    self.Vikna::Parent::remove-child: $child;
    self.dispatch: Event::Detached, :$child, :parent(self)
}

method cmd-clear() {
    $.for-children: { .clear },
                    post => { self.clear-canvas };
    self.invalidate;
    self.redraw;
}

method cmd-setbgpattern(Str $pattern) {
    my $old-bg-pattern = $!bg-pattern;
    $!bg-pattern = $pattern;
    self.dispatch: Event::Changed::BgPattern, :$old-bg-pattern, :$!bg-pattern;
    self.invalidate;
    self.redraw;
}

method cmd-sethidden($hidden) {
    if $hidden ^^ $!hidden {
        my $was-visible = $.visible;
        $!hidden = $hidden;
        $.dispatch: $!hidden ?? Event::Hide !! Event::Show;
        if $!hidden {
            $.parent.invalidate: $!geom;
            $.parent.redraw;
        }
        else {
            $.invalidate;
            $.redraw;
        }
        if $was-visible ^^ $.visible {
            $.dispatch: $.visible ?? Event::Visible !! Event::Invisible;
        }
    }
}

method cmd-close {
    my @completions;
    $.trace: "CLOSING";
    $.trace: "REMOVING SELF FROM PARENT";
    .remove-child(self) with $.parent;

    $.for-children: {
        @completions.push: .close.completed
    }
    $.trace: "AWAITING FOR CHILDREN TO CLOSE";
    await Promise.allof(@completions);
    $.trace: "FINISHING SELF";
    self.?finish;
    self.stop-event-handling;
}

method cmd-redraw(Promise:D $redrawn) {
    return unless $.visible;
    my Vikna::Canvas:D $canvas = $!canvas;
    my @cpromises;
    my @chld-canvas;
    $.trace: "REQ CHILDREN CANVAS";
    $.for-children: -> $chld {
        next unless $chld.visible;
        $.trace: "REQ FROM CHILD ", $chld.WHICH;
        @cpromises.push: $chld.send-command( Event::Cmd::CanvasReq ).response;
    };
    $.trace: "AWATING FOR CHILDREN RESPONSE";
    await Promise.allof(@cpromises) if @cpromises;
    $.trace: "DONE AWATING FOR CHILDREN RESPONSE";
    @chld-canvas = eager @cpromises.grep( { .status ~~ Kept } ).map: *.result;
    $.invalidate: .invalidations for @chld-canvas;
    $.trace: "CMD REDRAW: invalidations: ", @!invalidations.elems, "\n", @!invalidations.map( "  . " ~ *.Str ).join("\n");
    if @!invalidations {
        $.trace: "BEGIN DRAW";
        $canvas = self.begin-draw;
        self.draw( :$canvas );
        self.end-draw( :$canvas );
        $.trace: "END DRAW";
        for @chld-canvas {
            $.trace: " ... applying child canvas at {.geom.x},{.geom.y}";
            $canvas.imprint: .geom.x, .geom.y, .canvas;
        }
        # We've done drawing itself, wait for children to complete.
        $.trace: "ALL CHILDREN CANVAS IMPRINTED";
        $!canvas = $canvas;
        .redraw with $.parent;
    }
    LEAVE {
        $.trace: "REDRAWN";
        $redrawn.keep($.geom.clone);
    }
}

method cmd-canvasreq(Promise:D $response) {
    if $!canvas-geom && $.visible {
        my @invalidations;
        $.trace: "CANVAS REQ COMMAND\nHas ", $!inv-for-parent.elems, " invalidations for parent";
        cas $!inv-for-parent, {
            @invalidations = $_;
            []
        };
        $.trace: "CANVAS REQ: KEEPING THE RESPONSE";
        $response.keep( CanvasReqRecord.new: :@invalidations, :$!canvas, geom => $!canvas-geom );
        $.trace: "CANVAS REQ: KEPT THE RESPONSE";
    }
    else {
        $response.break( Nil )
    }
}

method cmd-setgeom(Vikna::Rect:D $geom) {
    $.trace: "? changing geom to ", $geom;
    my $from;
    cas $!geom, {
        $from = $_;
        $geom.clone
    };
    $.trace: "? setgeom invalidations";
    $.add-inv-parent-rect: $from;
    $.add-inv-parent-rect: $geom;
    $.invalidate;
    $.trace: "? setgeom redraw";
    $.redraw;
    $.trace: "? setgeom notify";
    self.dispatch: Event::Changed::Geom, :$from, to => $!geom
        if    $from.x != $!geom.x || $from.y != $!geom.y
           || $from.w != $!geom.w || $from.h != $!geom.h;
    my $view-rect = Vikna::Rect.new: 0, 0, $!geom.w, $!geom.h;
    $.for-children: {
        .set-invisible: ! $view-rect.overlap( .geom );
    }
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
    $.send-command: Event::Cmd::AddChild, $child;
}

method remove-child(::?CLASS:D $child) {
    $.send-command: Event::Cmd::RemoveChild, $child;
}

method redraw {
    $.trace: "SENDING REDRAW COMMAND";
    $.send-command: Event::Cmd::Redraw;
}

method clear {
    $.send-command: Event::Cmd::Clear;
}

method close {
    $.send-command: Event::Cmd::Close;
}

method resize(Dimension:D $w, Dimension:D $h) {
    $.send-command: Event::Cmd::SetGeom, $!geom.clone( :$w, :$h );
}

method move(Int:D $x, Int:D $y) {
    $.send-command: Event::Cmd::SetGeom, $!geom.clone( :$x, :$y );
}

multi method set-geom(Int:D $x, Int:D $y, Dimension:D $w, Dimension:D $h) {
    $.send-command: Event::Cmd::SetGeom, Vikna::Rect.new(:$x, :$y, :$w, :$h)
}

method set-color(BasicColor :$fg, BasicColor :$bg) {
    $.send-command: Event::Cmd::SetColor, :$fg, :$bg
}

method set-bg-pattern($pattern) {
    self.send-command: Event::Cmd::SetBgPattern, $pattern;
}

method set-hidden($hidden) {
    $.send-command: Event::Cmd::SetHidden, ?$hidden;
}

method hide { $.set-hidden: True }
method show { $.set-hidden: False }

method set-invisible($invisible) {
    my $changed;
    cas $!invisible, {
        $changed = $_ ^^ $invisible;
        $invisible
    };
    if $changed {
        $.dispatch: $.visible ?? Event::Visible !! Event::Invisible;
    }
}

method sync-events(:$transitive) {
    my @p;
    if $transitive {
        $.for-children: {
            @p.push: .nop.completed(:transitive);
        }
    }
    @p.push: $.nop.completed;
    await @p;
}

method nop {
    $.send-command: Event::Cmd::Nop
}

### State methods ###

method visible { ! ($!hidden || $!invisible) }

### Utility methods ###

method add-inv-parent-rect(Vikna::Rect:D $rect) {
    if $.parent {
        $.trace: "ADD TO STASH OF PARENT INVS: ", ~$rect;
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
    $.trace: "INVALIDATE ", ~$rect, "\n -> ", $.parent.WHICH, " as ", $rect.absolute($.geom);
    $.add-inv-rect: $rect;
}

multi method invalidate(UInt:D $x, UInt:D $y, Dimension $w, Dimension $h) {
    $.invalidate: Vikna::Rect.new( :$x, :$y, :$w, :$h )
}

multi method invalidate(UInt:D :$x, UInt:D :$y, Dimension :$w, Dimension :$h) {
    $.invalidate: Vikna::Rect.new( :$x, :$y, :$w, :$h )
}

multi method invalidate() {
    $.invalidate: Vikna::Rect.new( :0x, :0y, :$.w, :$.h );
}

multi method invalidate(@invalidations) {
    $.invalidate: $_ for @invalidations
}

method begin-draw(Vikna::Canvas $canvas? is copy --> Vikna::Canvas) {
    $!canvas-geom = $!geom.clone;
    $canvas //= $.create:
                    Vikna::Canvas,
                    geom => $!geom.clone,
                    :$!inv-mark-color,
                    |($!auto-clear ?? () !! :from($!canvas));
    $.invalidate if $!auto-clear;
    $.trace: "begin-draw canvas (auto-clear:{$!auto-clear}): ", $canvas.WHICH, " ", $canvas.w, " x ", $canvas.h;

    for @!invalidations {
        $canvas.invalidate: $_
    }

    $canvas
}

method end-draw( :$canvas! ) {
    $.trace: "END DRAW";
    $!inv-for-parent.append: @$!stash-parent-invs;
    $!stash-parent-invs = [];
    self.clear-invalidations;
    $.dispatch: Event::Updated, geom => $!canvas-geom;
}

method redraw-block {
    ++$!redraw-blocks;
    $.for-children: { .redraw-block };
}

method redraw-unblock {
    $.for-children: { .redraw-unblock };
    given --$!redraw-blocks {
        when 0 {
            self!release-redraw-event;
        }
        when * < 0 {
            self.throw: X::Redraw::OverUnblock, :count( .abs );
        }
    }
}

method redraw-hold(&code, |c) {
    $.redraw-block;
    LEAVE $.redraw-unblock;
    &code(|c)
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

method !release-redraw-event {
    # Don't release if redraws are blocked
    return if $!redraw-blocks;
    my $rh;
    cas $!redraw-on-hold, {
        # If there is a redraw event pending then release it into the wild.
        # self.trace: "RELEASE HELD EVENT with invs: ", $rh.invalidations.elems;
        $rh = $_;
        Nil
    };
    with $rh {
        $.trace: "Held redraw event: " ~ .WHICH;
        self.send-event: $_;
    }
}

method !hold-redraw-event($ev) {
    cas $!redraw-on-hold, {
        if $_ {
            $ev.redrawn.keep(True);
            $_
        }
        else {
            $ev
        }
    }
}

# Filters are protected from concurrency by EventHandling
multi method event-filter(Event::Cmd::Redraw:D $ev) {
    $.trace: "WIDGET EV FILTER: ", $ev.^name;
    if $!redraw-blocks == 0 && $!redraws.try_acquire {
        # There is no current redraws, we just proceed further but first make sure we release the resource when done.
        $ev.redrawn.then: {
            $.flow: :name('REDRAW RELEASE'), {
                $.trace: "RELEASING REDRAW SEMAPHORE";
                $!redraws.release;
                self!release-redraw-event;
            }
        };
        [$ev]
    }
    else {
        # There is another redraw active.
        $.trace: "PUT ", $ev.WHICH, " on hold";
        self!hold-redraw-event: $ev;
        # This event won't go any further...
        []
    }
}
