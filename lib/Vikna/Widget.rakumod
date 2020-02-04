use v6.e.PREVIEW;
unit class Vikna::Widget;
use Vikna::Object;
use Vikna::Parent;
use Vikna::Child;
use Vikna::EventHandling;

also is Vikna::Object;
also does Vikna::Parent[::?CLASS];
also does Vikna::Child;
also does Vikna::EventHandling;

use Vikna::Rect;
use Vikna::Events;
use Vikna::X;
use Vikna::Color;
use Vikna::Canvas;
use Vikna::Utils;
use AttrX::Mooish;

my class CanvasRecord {
    has Vikna::Rect:D $.geom is required;
    has Vikna::Canvas:D $.canvas is required;
}

has $.name is mooish(:lazy);

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

has Promise:D $!closed .= new;
has Promise:D $.dismissed .= new;

has Event $!redraw-on-hold;
has Semaphore:D $!redraws .= new(1);
has atomicint $!redraw-blocks = 0;

has @.invalidations;
has Lock $.inv-lock .= new;
# Invalidations mapped into parent's coords. To be pulled out together with widget canvas for imprinting into parent's
# canvas.
has $!stash-parent-invs = []; # Invalidations for parent widget are to be stashed here first ...
has $!inv-for-parent = [];    # ... and then added here when redraw finalizes
has Lock:D $!inv4parent-lock .= new;

# Keys are Vikna::Object.id
has %!child-by-id;
has %!child-by-name; # Maps name into id

has $.inv-mark-color is rw; # For test purposes only.

multi method new(Int:D $x, Int:D $y, Dimension $w, Dimension $h, *%c) {
    self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
}

multi method new(Int:D :$x, Int:D :$y, Dimension :$w, Dimension :$h, *%c) {
    self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
}

multi method new(*%c where { $_<geom>:!exists }) {
    self.new: geom => Vikna::Rect.new(:0x, :0y, :20w, :10h), |%c
}

method build-name {
    self.^name ~ "<" ~ $.id ~ ">"
}

method build-canvas {
    $.create: Vikna::Canvas, geom => $!geom.clone;
}

method create-child(Vikna::Widget:U \wtype, |c) {
    $.trace: "CREATING A CHILD OF ", wtype.^name;
    my $child = $.create: wtype, |c;
    $.trace: "NEW CHILD: ", $child.name, " // ", $child.WHICH;
    self.add-child: $child;
    $child
}

method subscribe-to-child(Vikna::Widget:D $child) {
    self.subscribe: $child, -> $ev {
        # Redispatch only informative events as all we may need is to be posted about child changes.
        self.child-event($ev) if $ev ~~ Event::Informative
    };
}

proto method event(::?CLASS:D: Event:D $ev) {*}
#     {*}
#
#     # Commands are not to be re-dispatched to children. If any changes in children are required they're to be initiated
#     # via their respective methods.
#     unless $ev ~~ Event::Command || $ev.dispatcher !=== self {
#         self.for-children: {
#             .event($ev) unless $_ === $ev.dispatcher | $ev.origin;
#         }
#     }
#     CONTROL {
#         when CX::Event::Last {
#             $.trace: "STOP EVENT HANDLING for ", $ev.^name;
#         }
#         default {
#             .rethrow
#         }
#     }
# }

multi method event(::?CLASS:D: Event::Command:D $ev) {
    # Only process commands sent by ourselves. Protect from stray events.
    $.throw: X::Event::CommandOrigin, :$ev, dest => self
        unless $ev.origin === self;
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
        $ev.complete( self."$cmd-name"( |$ev.args ) );
        CATCH {
            default {
                note "Failed keeping completed promise on $ev: ", ~($ev.completed-at // "*no idea where*");
                $.trace: "EVENT {$ev} HAS BEEN COMPLETED AT ", ~($ev.completed-at // "*no idea where*"),
                        "\n", .message ~ .backtrace,
                        :error;
                $.panic: $_
            }
        }
    }
    elsif self.^can('CMD-FALLBACK') {
        $.trace: "PASSING TO CMD-FALLBACK";
        $ev.complete( self.CMD-FALLBACK($ev) );
    }
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
    if $ev.parent === self {
        $.invalidate: $ev.child.geom;
    }
}

multi method event(::?CLASS:D: Event::Detached:D $ev) {
    if $ev.child === self {
        if $.closed {
            # If a closed widget gets detached it's time to stop every activity.
            $.shutdown;
        }
    }
    elsif $ev.parent === self {
        $.redraw;
    }
}

proto method child-event(::?CLASS:D: Event:D) {*}

# multi method child-event(::?CLASS:D: Event::Updated:D $ev) {
#     $.trace: "CHILD ", $ev.origin.WHICH, " updated";
#     $.redraw;
# }

multi method child-event(::?CLASS:D: Event::Closing:D $ev) {
    $.invalidate: $ev.origin.geom;
    $.redraw;
}

multi method child-event(::?CLASS:D: Event::Changed::Geom:D $ev) {
    $.trace: "CHILD {$ev.origin} GEOM CHANGED {$ev.from} => {$ev.to}";
    $.invalidate: [ $ev.from, $ev.to ];
    $.redraw;
}

multi method child-event(::?CLASS:D: Event:D)        { }

proto method subscription-event(::?CLASS:D: Event:D) {*}
multi method subscription-event(::?CLASS:D: Event:D) { }

proto method drop-event(::?CLASS:D: Event:D)  {*}
multi method drop-event(Event::Command:D $ev) {
    $.trace: "DROPPING ", $ev;
    $ev.complete(False);
}
multi method drop-event(Event:D)              { }

### Command handlers ###

method cmd-addchild(::?CLASS:D: Vikna::Widget:D $child, :$subscribe = True) {
    $.trace: "ADDING CHILD ", $child.name;

    my $child-name = $child.name;
    $.throw: X::Widget::DuplicateName, :parent(self), :name($child-name)
        if %!child-by-name{$child-name}:exists;

    if self.Vikna::Parent::add-child: $child {
        $.trace: " ADDED CHILD ", $child.name, " with parent: ", $child.parent.name;
        %!child-by-id{
            %!child-by-name{$child-name} = $child.id;
        } = %( :$child );
        # note self.name, " ADDED CHILD ", $child.name, " with parent: ", $child.parent.name;
        self.subscribe-to-child($child) if $subscribe;
        $child.invalidate;
        $child.redraw;
        $child.dispatch: Event::Attached, :$child, :parent(self);
        self.dispatch:   Event::Attached, :$child, :parent(self);
    }
}

method cmd-removechild(::?CLASS:D: Vikna::Widget:D $child, :$unsubscribe = True) {
    self.unsubscribe: $child if $unsubscribe;
    # If a child is closing then we're its last parent and have to wait until it fully dismisses. Otherwise the child is
    # going to stick around for a while and somebody else must take care of it. Most likely it's re-parenting taking
    # place.
    %!child-by-id{$child.id}:delete;
    %!child-by-name{$child.name}:delete;
    if $child.closed {
        $child.dismissed.then: {
            self.Vikna::Parent::remove-child: $child;
            self.dispatch: Event::Detached, :$child, :parent(self);
        }
    }
    else {
        self.Vikna::Parent::remove-child: $child;
        self.dispatch: Event::Detached, :$child, :parent(self);
    }
    $child.dispatch: Event::Detached, :$child, :parent(self);
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
    return if $.closed;
    $.trace: "CLOSING";
    $!closed.keep(True);

    my @dismissed;
    $.for-children: {
        @dismissed.push: .dismissed;
        # Don't bother if child is already closing. Slightly relieve event flood.
        next if .closed;
        .close
    }
    $.dispatch: Event::Closing;
    Promise.allof(@dismissed).then: {
        $.trace: "CHILDREN DISMISSED, DETACHING";
        $.detach;
    };
}

method !flatten-canvas {
    $.for-children: -> $child {
        # Newly added children might not have drawn yet. It's ok to skip 'em.
        next unless $child.visible;
        $!canvas.imprint: .geom.x, .geom.y, .canvas with %!child-by-id{$child.id}<canvas>;
    }
    .child-canvas: self, $!canvas-geom, $!canvas, $!inv-for-parent with $.parent;
    $!inv4parent-lock.protect: {
        $!inv-for-parent = [];
    }
    $.dispatch: Event::Updated, geom => $!canvas-geom;
}

method cmd-redraw() {
    return unless $.visible;
    if $.redraw-blocked {
        $.trace: "SKIP REDRAW UNTIL UNBLOCKED";
        $.redraw;
    }
    else {
        my Vikna::Canvas:D $canvas = $!canvas;
        $.trace: "CMD REDRAW: invalidations: ", @!invalidations.elems, "\n", @!invalidations.map( "  . " ~ *.Str ).join("\n");
        if @!invalidations {
            $.trace: "STARTED DRAW";
            $canvas = self.begin-draw;
            self.draw( :$canvas );
            self.end-draw( :$canvas );
            $.trace: "FINISHED DRAW";
            $!canvas = $canvas;
            self!flatten-canvas;
            $.trace: "REDRAWN";
        }
    }
}

method cmd-childcanvas(::?CLASS:D $child, Vikna::Rect:D $canvas-geom, Vikna::Canvas:D $canvas, @invalidations) {
    $.trace: "CHILD CANVAS FROM ", $child.name, " AT {$canvas-geom} WITH ", +@invalidations, " INVALIDATIONS:\n",
                @invalidations.map({ "  " ~ $_ }).join("\n");
    %!child-by-id{$child.id}<canvas> = CanvasRecord.new: :$canvas, geom => $canvas-geom;
    if @invalidations {
        $.invalidate: @invalidations;
    }
}

method cmd-setgeom(Vikna::Rect:D $geom, :$no-draw?) {
    $.trace: "Changing geom to ", $geom;
    my $from;
    cas $!geom, {
        $from = $_;
        $geom.clone
    };
    $.trace: "Setgeom invalidations";
    $.add-inv-parent-rect: $from;
    $.invalidate;
    unless $no-draw {
        $.trace: "Setgeom children visibility";
        my $view-rect = Vikna::Rect.new: 0, 0, $!geom.w, $!geom.h;
        $.for-children: {
            .set-invisible: ! $view-rect.overlap( .geom );
        }
        $.trace: "Setgeom redraw";
        $.redraw;
    }
    self.dispatch: Event::Changed::Geom, :$from, to => $!geom
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
multi method send-command(Event::Command:U \evType, |args) {
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

method child-canvas(::?CLASS:D $child, Vikna::Rect:D $canvas-geom, Vikna::Canvas:D $canvas, @invalidations) {
    $.trace: "COMMAND child-canvas for child ", $child.name, " with ", +@invalidations, " invalidations";
    my $ev = $.send-command: Event::Cmd::ChildCanvas, $child, $canvas-geom, $canvas, @invalidations;
    # $.trace: "{$ev} {$canvas.w} x {$canvas.h}, invalidations:", @invalidations.map({ "\n  $_" });
    $.redraw;
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
multi method set-geom(Vikna::Rect:D $rect) {
    $.send-command: Event::Cmd::SetGeom, $rect
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
    my $irresponsive = [];
    if $transitive {
        $.for-children: -> $chld {
            @p.push: %( widget => $chld, promise => $chld.nop.completed(:transitive) );
        }
    }
    @p.push: %( widget => self, promise => $.nop.completed );
    $.trace: "LIST OF NOPS:\n", @p.map({ "  " ~ .<widget>.name ~ " p:" ~ .<promise>.^name }).join("\n");
    my $succeed = False;
    await Promise.anyof(
        Promise.in(30),
        $.flow: :name('SYNC EVENTS'), { await eager @p.map( { $_<promise> } ); $succeed = True; }
    );
    unless $succeed {
        for @p {
            note $_<widget>.WHICH, " nop ", $_<promise>.?status.^name;
        }
        note $.name ~ " INTERNAL: {$transitive ?? "transitive " !! ""}sync-events timeout exceeded";
        self.panic: X::AdHoc.new: payload => $.name ~ " INTERNAL: {$transitive ?? "transitive " !! ""}sync-events timeout exceeded";
    }
}

method nop {
    # note self.name, " NOP";
    $.send-command: Event::Cmd::Nop
}

### State methods ###

method visible { ! ($!hidden || $!invisible || $.closed) }

method closed { ! ($!closed.status ~~ Planned) }

### Utility methods ###

method add-inv-parent-rect(Vikna::Rect:D $rect) {
    if $.parent {
        $.trace: "ADD TO STASH OF PARENT INVS: ", ~$rect;
        $!inv4parent-lock.protect: {
            $!stash-parent-invs.push: $rect
        }
    }
}

method add-inv-rect(Vikna::Rect:D $rect) {
    $!inv-lock.protect: {
        @!invalidations.push: $rect;
    }
    $.add-inv-parent-rect: $rect.absolute($!geom);
}

method clear-invalidations {
    $!inv-lock.protect: {
        @!invalidations = [];
    }
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

multi method invalidate(@invalidations) {
    $.invalidate: $_ for @invalidations
}

multi method invalidate() {
    $.invalidate: Vikna::Rect.new( :0x, :0y, :$.w, :$.h );
}

method begin-draw(Vikna::Canvas $canvas? is copy --> Vikna::Canvas) {
    $!canvas-geom = $!geom.clone;
    $canvas //= $.create:
                    Vikna::Canvas,
                    :$.w, :$.h,
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
    $!inv4parent-lock.protect: {
        $!inv-for-parent.append: @$!stash-parent-invs;
        $!stash-parent-invs = [];
    }
    self.clear-invalidations;
}

method redraw-block {
    ++$!redraw-blocks;
    $.trace: "REDRAW BLOCK, block count: ", $!redraw-blocks;
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
    $.trace: "REDRAW UNBLOCK, block count: ", $!redraw-blocks;
}

method redraw-blocked { ? $!redraw-blocks }

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
        $.trace: "DRAWING BACKGROUND";
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
    if $rh && !$.closed {
        $.trace: "Held redraw event: " ~ $rh;
        self.send-event: $rh unless $.closed;
    }
}

method !hold-redraw-event($ev) {
    my $drop;
    # cas block can be ran more than once. Thus, no irreversible actions should be done and $drop flag must be set on
    # both branches of if for consistency.
    cas $!redraw-on-hold, {
        if $_ {
            $.trace: "ALREADY HOLDING ", $_;
            $drop = True;
            $_
        }
        else {
            $.trace: "RECORDING FOR HOLD ", $ev;
            $drop = False;
            $ev
        }
    };
    $.drop-event: $ev if $drop;
}

# Filters are protected from concurrency by EventHandling
multi method event-filter(Event::Cmd::Redraw:D $ev) {
    $.trace: "WIDGET EV FILTER: ", $ev, ", redraw blocks: $!redraw-blocks";
    if $!redraw-blocks == 0 && $!redraws.try_acquire {
        # There is no current redraws, we just proceed further but first make sure we release the resource when done.
        $ev.completed.then: {
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
        $.trace: "PUT ", $ev, " on hold";
        self!hold-redraw-event: $ev;
        # This event won't go any further...
        []
    }
}

method detach {
    with $.parent {
        .remove-child: self;
    }
    else {
        $.dispatch: Event::Detached, :child(self), :parent(self);
    }
}

method shutdown {
    $.stop-event-handling.then: {
        $!dismissed.keep(True);
    }
}

proto method get-child(::?CLASS:D: |) {*}
multi method get-child(Str:D $name --> Vikna::Widget) {
    %!child-by-name{$name}:exists ?? %!child-by-id{ %!child-by-name{$name} }<child> !! Nil
}
multi method get-child(Int:D $id --> Vikna::Widget) {
    %!child-by-id{$id}:exists ?? %!child-by-id{$id}<child> !! Nil
}

proto method AT-KEY(|) {*}
multi method AT-KEY(::?CLASS:D: Str:D $wname) {
    %!child-by-name{$wname} ?? %!child-by-id{ %!child-by-name{$wname} }<child> !! Nil
}
multi method AT-KEY(::?CLASS:D: Int $id) {
    %!child-by-id{ $id }<child>
}
multi method AT-KEY(::?CLASS:U: |) { Nil }

proto method EXISTS-KEY(|) {*}
multi method EXISTS-KEY(::?CLASS:D: Str:D $wname) {
    %!child-by-name{$wname}:exists
}
multi method EXISTS-KEY(::?CLASS:D: Int:D $id) {
    %!child-by-id{$id}:exists
}
multi method EXISTS-KEY(::?CLASS:U: |) { False }

proto method DELETE-KEY(|) {*}
multi method DELETE-KEY(::?CLASS:D: Str:D $wname) {
    $.remove-child: $_ with $.get-child($wname);
}
multi method DELETE-KEY(::?CLASS:D: Int:D $id) {
    $.remove-child: $_ with $.get-child($id);
}
