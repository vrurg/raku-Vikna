use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Widget> - the base of all widgets

=DESCRIPTION

...

=head2 Flattening Canvas

After a widget has drawn itself Vikna takes a number of step to ensure it is imprinted correctly on its parent and,
eventually, on the screen. The process is called I<flattening> because figuratively it could be described as if
Z-order of children canvas is flattened down into parent's canvas. Here is how this happens.

Many good stories starts from the end. This one does it too. Let's skip all preceding steps and say that widget sends
it's ready canvas (BTW, it is internally called imPrinted canvas and abbreviated to just C<pcanvas>) and all current
invalidations (converted into parent's coordinate system) to the parent. At this point widget's work is over and it
clears all invalidations. The next cycle starts now.

Meanwhile, the parent receives C<Event::Cmd::ChildCanvas> and records the received object in its local registry. The
invalidations which came with the command event are appended to the list of local invalidations. This is where the
story starts because the parent immediately initiates the I<flattening>. From this moment on we stop using term
I<parent> and using just I<widget> again.

The first step is checking if the flattening is not blocked for a reason. If so, we increase flatten miss counter and
leave. When all blockers are done, the framework checks the counter and initiates immediate flattening.

Now, we need to prepare C<pcanvas>. Normally, if widget dimensions are not changed, C<pcanvas> is preserved across
flattening cycles and only updated using invalidations. It somewhat speeds up the flattening process by avoiding
extra object allocations and copying of full canvas content each time, especially if only tiny bits of widget are
updated.

If there is no block installed, then currently active invalidations are applied to C<pcanvas>. Then widget imprints
own canvas on C<pcanvas> and all collected children canvas from the local registry unless a child is invisible. It
means that if a child was created and attached but never sent its canvas up to the parent – it would never be displayed.

Children are also get notified of their canvas is used with C<Event::Updated>.

Once again, note that imprinting will only change the areas of the widget which were invalidated either by the widget
itself or by mapped invalidations from children. A good example of how it works would be the following scheme:

    ...............
    .. Label ......
    ...............

The dots represent a parent widget with a L<C<Vikna::Label>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Label.md> child attached. Then, say, we change the label text. No
other changes were done. Then the only area on C<pcanvas> which will be affected by flattening will be the one-line
rectangle at C<(x:2, y:1, w:7, h:1)> granted that text change doesn't change label's dimentions. If the parent widget
is really big this optimization would save us a whole lot copying over! Moreover, the invalidation will then be
propagated further upstream resulting in the same little changes done in all parents up until the desktop and screen
themselve.

At this point flattening down of canvas is almost done. If widget has a parent, it invokes C<child-canvas> command
method on it with C<pcanvas> and mapped invalidations.

If the widget is the top one (i.e. the desktop) then it calls command method C<print> with C<pcanvas>. C<Event::Updated>
is then sent to self as if our parent notified us of imprint taken place.

And so, the story closes the cycle...

=ATTRIBUTES

=head3 C<L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md>:D $.geom>

Widget geometry in its parent coordinate system.

=head3 C<L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> $.viewport>

Visible part of the widget in its parent coordinate system. To be more precise, this is widget's C<$.geom> clipped by
parent's viewport. In the scheme below 1 is our viewport area. It might be even smaller if the parent itself isn't fully
visible.

               +---------+
    +---- Parent ----+   |
    |          |  1  | 2 |
    |          +-----|---+
    +----------------+

=head3 C<L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> $.abs-geom>

Widget geometry in absolute coordinate system. By I<absolute> we take the screen, but because the desktop object is
assumed to occupy the whole screen, all absolute coordinates are taken relatively to desktop.

=head3 C<L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> $.abs-viewport>

Similar to C<$.abs-geom>, but for C<$.viewport>.

=head3 C<L<Vikna::WAttr|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md>:D $.attr>

Widget default attributes.

=head3 C<Bool:D $.auto-clear>

If I<True> then every new draw operation starts with a fresh canvas. Otherwise new canvas get its content from the
last draw operation.

=head3 C<Bool:D $.hidden>

If I<True> then widget is intentionally hidden on its parent.

=head3 C<Bool:D $.invisible>

If I<True> then widget is outside of parent's viewport and thus not visible on the screen. The difference with
C<$.hidden> attribute is that the latter is set intentionally, while this attribute is a result of calculations of
widget position.

=head3 C<L<Vikna::Canvas|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md> $.canvas>

Widget canvas after the last redraw operation.

=head3 C<Promise:D $.dismissed>

This promise is kept with I<True> when widget has shutdown. In particular, its event loop has been stopped.

=head3 C<@.invalidations>

List of invalidation rectangles. Is used for the next redraw operation and cleared after flattened down canvas were
sent over to the parent.

=METHODS

=head3 C<submethod profile-checkin(%profile, $constructor, %, %)>

The default widget profile checkin is responsible for the following operations:

=item it converts C<x>, C<y>, C<w>, C<h> profile keys into C<geom> by creating a new
L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> instance unless C<geom> is defined explicitly
=item it converts C<fg>, C<bg>, C<style>, and C<pattern> profile keys into C<attr> by creating a new
L<C<Vikna::WAttr>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md> instance

All mentioned above source keys are unconditionally deleted from C<%profile>.

=head3 C<create-child(Vikna::Widget:U \widgetType, ChildStrata $stratum = StMain, *%p)>

Create a new widget child. The child is created detached and C<Event::Init> is dispatched on it instantly. Then it is
added to the widget with C<add-child> method.

Returns the child object.

=head3 C<subscribe-to-child(Vikna::Widget:D $child)>

Method subscribes self to child events and passes them to widget's C<child-event> handler method.

=head3 C<multi route-event(Event::Spreadable:D $ev)>

Re-dispatches C<$ev> to child widgets.

=head3 C<multi child-event(Event:D)>

Proto defined to handle children events if subscribed to a child. By default does nothing.

=head3 C<subscription-event(Event:D $ev)>

Proto defined to handle any other subscription events. By default does nothing.
See L<C<Vikna::EventHandling>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventHandling.md> role.

=head3 C<flatten-canvas()>

Normally one doesn't need this method except special care is required to guarantee correct imprinting of a object on
its parent.

See L<#Canvas Flattening> section above.

=head2 Command Methods

This is a group of methods which sends command events to the widget. Normally they're just shortcuts for
L<C<Event::CommandHandling>|https://modules.raku.org/dist/Event::CommandHandling>
C<send-command> method. Because this is what user must interact with, C<cmd-*> methods are not documented. Their
specifics will be elaborated on in description of command methods.

=head3 C<add-child(Vikna::Widget:D $child, ChildStrata $stratum = StMaian, :$subscribe = True)>

C<Event::Cmd::AddChild>. Adds a new child to the widget. This includes subscribtion to child events if C<$subscribe>
is I<True>.

Upon successfull addition C<Event::Attached> is dipatched on both the child and self. If the added child becomes
the topmost one on strata, C<Event::ZOrder::Top> is dispatched on the child and C<Event::ZOrder::Child> on self.

=head3 C<remove-child($child)>

C<Event::Cmd::RemoveChild>. Removes a child from the widget children list. Emits C<Event::Detached> on the child.

A child could be removed from its parent for two reasons: either it is closing or it is switching to another parent.
The command considers both situation. If the child is closing, then the widget awaits until it becomes C<$.dismissed>
before finalizing the removal. Otherfile finalization takes place immediately.

The finalization of child removal does:

=item dispatches C<Event::Detached> on self
=item redraws the widget to update the area previously occupied by the child.

Corresponding C<Event::ZOrder::*> events are dispatched if necessary.

=head3 C<child-canvas(Vikna::Widget:D $child, Vikna::Rect:D $canvas-geom, Vikna::Canvas::D $canvas, @invlidations)>

C<Event::Cmd::ChildCanvas>. Register updated child canvas on the widget. Must not be used by user code normally.

Part of the L<#Canvas Flattening> process. A child sends this command every time its own C<pcanvas> is updated.

=head3 C<redraw()>

C<Event::Cmd::Redraw>. Request the widget to redraw itself. The action might not happen in on of the cases:

=item when widget is C<$.invisible>
=item if redraws are blocked on the widget (see C<redraw-block> method)
=item if the widget doesn't have any invalidations registered

When drawing is possible, new canvas is created by C<begin-draw> method and passed to widget method C<draw>. When it's
done C<end-draw> is invoked with the same canvas object which is then set as widget's C<$.canvas>. At the end widget
flattens canvas, as described in L<#Canvas Flattening>.

=head3 C<to-top(Vikna::Widget:D $child)>

C<Event::Cmd::To::Top>. Sends a C<$child> to the top of Z-order within it's stratum. Then invalidates the rectangle
occupied by the child and flattens canvas.

C<Event::ZOrder::Top> is dispatched on the child, C<Event::ZOrder::Child> is dispatched on self.

=head3 C<maybe-to-top()>

Normally does nothing. It is used by L<C<Vikna::Elevatable>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Elevatable.md>
role to signal to a widget it is applied to there is an event happened to which the widget can respond by elevating
itself to the top of Z-order.

For example see L<C<Vikna::Window>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Window.md>.

=head3 C<clear()>

C<Event::Cmd::Clear>. The command is bypassed down to widget children too. Then fully invalidates and redraws the
widget.

=head3 C<resize($w, $h)>

Shortcut for C<set-geom> method with preserved widget coordinates.

=head3 C<move($x, $y)>

Shortcut for C<set-geom> method with preserved widget dimensions

=head3 C<multi set-geom($x, $y, $w, $h)>
=head3 C<multi set-geom(Vikna::Rect:D $geom)>

C<Event::Cmd::SetGeom>. Method changes widget geometry on its parent. It has the following side effects:

=item widget position information is updated by C<update-positions> method.
=item widget is invalidated as a whole
=item the old widget rectangle is invalidated on its parent
=item position information is updated on children
=item widget redraw is initiated

C<Event::Changed::Geom> is dispatched on self if the requested geometry differs from the previous one.

=head3 C<close()>

C<Event::Cmd::Close>. Close the widget.

Firs, the command is bypassed down to the widget children. C<Event::Closing> is dispatched on self. Then the widget
awaits for all children to dismiss and when they have detaches itself from the parent. Then see C<detach> method
description.

=head3 C<quit()>

Shortcut for quitting the whole application. A child widget invokes C<quit> method on the desktop. The desktop closes
itself.

=head3 C<detach()>

If the widget has a parent then invokes C<remove-child> on it for self. Otherwise we're the desktop widget and only
dispatch C<Event::Detached> on self with event C<child> attribute set to C<self> too.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md>,
L<C<Vikna::Object>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Object.md>,
L<C<Vikna::Parent>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Parent.md>,
L<C<Vikna::Child>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Child.md>,
L<C<Vikna::EventHandling>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventHandling.md>,
L<C<Vikna::CommandHandling>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CommandHandling.md>,
L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md>,
L<C<Vikna::Events>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Events.md>,
L<C<Vikna::Color>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Coloe.md>,
L<C<Vikna::Canvas>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md>,
L<C<Vikna::Utils>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Utils.md>,
L<C<Vikna::WAttr>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md>,
L<C<AttrX::Mooish>|https://modules.raku.org/dist/AttrX::Mooish>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

unit class Vikna::Widget;
use Vikna::Object;
use Vikna::Parent;
use Vikna::Child;
use Vikna::EventHandling;
use Vikna::CommandHandling;

also is Vikna::Object;
also does Vikna::Parent[::?CLASS];
also does Vikna::Child;
also does Vikna::EventHandling;
also does Vikna::CommandHandling;

use Vikna::Rect;
use Vikna::Events;
use Vikna::X;
use Vikna::Color;
use Vikna::Canvas;
use Vikna::Utils;
use Vikna::WAttr;
use AttrX::Mooish;

my class CanvasRecord {
    has Vikna::Rect:D $.geom is required;
    has Vikna::Canvas:D $.canvas is required;
    has @.invalidations;
}

my class AbsolutePosition {
    has Vikna::Rect $.geom;
    has Vikna::Rect $.visible;
}

has Vikna::Rect:D $.geom is required handles <x y w h>;
#| Visible part of the widget relative to the parent.
has Vikna::Rect $.viewport;
#| Rectange in absolute coordinates of the top widget (desktop)
has Vikna::Rect $.abs-geom;
#| Visible rectange of the vidget in it's parent in absolute coords.
has Vikna::Rect $.abs-viewport;

has Vikna::WAttr:D $.attr is required handles«fg bg style :bg-pattern<pattern>»;
has Bool:D $.auto-clear = False;
# Is widget invisible on purpose?
has Bool:D $.hidden = False;
# Is widget visible within its parent?
has Bool:D $.invisible = False;
has Vikna::Canvas $.canvas is mooish( :lazy, :clearer, :predicate );
# Printed canvas for parent
has Vikna::Canvas $!pcanvas;
# Widget's geom at the moment when canvas has been drawn.
has Vikna::Rect $!canvas-geom;

has Promise:D $!closed .= new;
has Promise:D $.dismissed .= new;

has Event $!redraw-on-hold;
has Semaphore:D $!redraws .= new( 1 );
has atomicint $!redraw-blocks = 0;
has atomicint $!flatten-blocks = 0;
# Block canvas flattenning
has atomicint $!flatten-misses = 0;
# Count of requests missed while awaiting for unblock

has @.invalidations;
has Lock $.inv-lock .= new;

# Invalidations mapped into parent's coords. To be pulled out together with widget canvas for imprinting into parent's
# canvas.
# Invalidations for parent widget are to be stashed here first ...
has $!stash-parent-invs = [];
# ... and then added here when redraw finalizes
has $!inv-for-parent = [];
has Lock:D $!inv4parent-lock .= new;

# Keys are Vikna::Object.id
has %!child-by-id;
# Maps name into id
has %!child-by-name;

has $.inv-mark-color is rw;
# For test purposes only.

# multi method new(Int:D $x, Int:D $y, Dimension $w, Dimension $h, *%c) {
#     self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
# }
#
# multi method new(Int:D :$x, Int:D :$y, Dimension :$w, Dimension :$h, *%c) {
#     self.new: geom => Vikna::Rect.new(:$x, :$y, :$w, :$h), |%c
# }
#
# multi method new(*%c where { $_<geom>:!exists }) {
#     self.new: geom => Vikna::Rect.new(:0x, :0y, :20w, :10h), |%c
# }

submethod TWEAK {
    self.update-positions;
}

submethod profile-default {
    :0x, :0y, :20w, :10h
}

submethod profile-checkin( %profile, %constructor, %, % ) {
    unless %profile<geom> {
        %profile<geom> = Vikna::Rect.new(%profile<x y w h>)
    }
    unless %profile<attr> ~~ Vikna::WAttr {
        # Constructor-defined keys override those from other sources.
        %profile<attr>{$_} = %constructor<attr>{$_} // %constructor{$_} // %profile<attr>{$_} // %profile{$_}
        for <fg bg style pattern>;
        %profile<attr> = wattr(|%profile<attr><fg bg style pattern>)
    }
    %profile<fg bg style pattern x y w h>:delete;
}

method build-canvas {
    self.create: Vikna::Canvas, geom => $!geom.clone;
}

method create-child( Vikna::Widget:U \wtype, ChildStrata $stratum = StMain, *%p ) {
    self.trace: "CREATING A CHILD OF ", wtype.^name;
    my $child = self.create: wtype, |%p;
    $child.dispatch: Event::Init;
    self.trace: "NEW CHILD: ", $child.name, " // ", $child.WHICH;
    self.add-child: $child, $stratum;
    $child
}

method subscribe-to-child( Vikna::Widget:D $child ) {
    self.subscribe: $child, -> $ev {
        # Redispatch only informative events as all we may need is to be posted about child changes.
        self.child-event($ev) if $ev ~~ Event::Informative
    };
}

multi method route-event( ::?CLASS:D: Event::Spreadable:D $ev is copy, *% ) {
    self.trace: "REDISPATCHING A SPREADABLE DEFINITE ", $ev;
    self.flow: :name( ‘Spreadable:D -> children’ ), {
        self.for-children: {
            # Set dispatcher to child because this is how a spreadable event produced from a type object would have
            # it set.
            self.trace: "SUBMIT SPREADABLE TO CHILD ", .name;
            .dispatch: $ev.clone(:dispatcher( $_ ))
        }
    }
    nextsame
}

multi method event( ::?CLASS:D: Event::Detached:D $ev ) {
    if $ev.child === self {
        if $.closed {
            # If a closed widget gets detached it's time to stop every activity.
            self.shutdown;
        }
    }
}
multi method event( ::?CLASS:D: Event::Attached:D $ev ) {
    if $ev.child === self {
        self.update-positions: :transitive;
        self.dispatch: Event::Ready;
    }
}

proto method child-event( ::?CLASS:D: Event:D ) {*}
multi method child-event( ::?CLASS:D: Event:D ) {}

proto method subscription-event( ::?CLASS:D: Event:D ) {*}
multi method subscription-event( ::?CLASS:D: Event:D ) {}

### Command handlers ###

method !top-child-changed( ChildStrata:D $stratum ) {
    # Take the current topmost child.
    with self.children($stratum).tail {
        .dispatch: $.is-bottommost( $_ ) ?? Event::ZOrder::Bottom !! Event::ZOrder::Middle;
    }
}

method cmd-addchild( ::?CLASS:D: Vikna::Widget:D $child, ChildStrata:D $stratum, :$subscribe = True ) {
    self.trace: "ADDING CHILD ", $child.name;

    my $child-name = $child.name;
    self.throw: X::Widget::DuplicateName, :parent( self ), :name( $child-name )
    if %!child-by-name{$child-name}:exists;

    if $.elems( $stratum ) {
        self!top-child-changed($stratum)
    }

    if self.Vikna::Parent::add-child($child, :$stratum) {
        self.trace: " ADDED CHILD ", $child.name, " with parent: ", $child.parent.name;
        %!child-by-id{ %!child-by-name{$child-name} = $child.id } = %( :$child);
        # note self.name, " ADDED CHILD ", $child.name, " with parent: ", $child.parent.name;
        self.subscribe-to-child($child) if $subscribe;
        $child.dispatch: Event::Attached, :$child, :parent( self );
        self.dispatch:   Event::Attached, :$child, :parent( self );
        if $.is-topmost( $child, :on-strata ) {
            $child.dispatch: Event::ZOrder::Top;
            self.dispatch:   Event::ZOrder::Child, :$child;
        }
        $child.invalidate;
        $child.redraw;
    }
}

method cmd-removechild( ::?CLASS:D: Vikna::Widget:D $child, :$unsubscribe = True ) {
    self.unsubscribe: $child if $unsubscribe;
    # If a child is closing then we're its last parent and have to wait until it fully dismisses. Otherwise the child is
    # going to stick around for a while and somebody else must take care of it. Most likely it's re-parenting taking
    # place.
    %!child-by-id{$child.id}:delete;
    %!child-by-name{$child.name}:delete;
    my $is-topmost = $.is-topmost( $child );
    my $is-bottommost = $.is-bottommost( $child );
    my $stratum = $.child-stratum( $child );
    my $cgeom = $child.geom;
    my sub remove-finally {
        self.dispatch: Event::Detached, :$child, :parent( self );
        self.invalidate: $cgeom;
        self.redraw;
    }
    self.Vikna::Parent::remove-child: $child;
    $child.dispatch: Event::Detached, :$child, :parent( self );
    if $child.closed {
        self.trace: "CHILD ", $child.name, " CLOSED, awaiting dismissal; current dismiss status is ", $child.dismissed
            .status;
        $child.dismissed.then: {
            self.trace: "CHILD ", $child.name, " DISMISSED, removing from list";
            remove-finally;
        }
    }
    else {
        remove-finally;
    }
    if $.elems( $stratum ) {
        if $is-topmost {
            my $top = $.children.tail;
            $top.dispatch: Event::ZOrder::Top unless $top.closed
        }
        if $is-bottommost {
            my $bottom = $.children.head;
            $bottom.dispatch: Event::ZOrder::Bottom unless $bottom.closed;
        }
    }
}

method cmd-clear( ) {
    self.for-children: { .clear }, post => { self.clear-canvas };
    $.invalidate;
    $.cmd-redraw;
}

method cmd-setbgpattern( Str $pattern ) {
    self.trace: "SET BG PATTERN to ‘$pattern’";
    my $from = $!attr.pattern;
    $!attr.pattern = $pattern;
    self.dispatch: Event::Changed::BgPattern, :$from, :to( $pattern );
    self.invalidate;
    self.redraw;
}

method cmd-sethidden( $hidden ) {
    if $hidden ^^ $!hidden {
        my $was-visible = $.visible;
        $!hidden = $hidden;
        self.dispatch: $!hidden ?? Event::Hide !! Event::Show;
        unless $!hidden {
            $.invalidate;
            $.redraw;
        }
        if $was-visible ^^ $.visible {
            self.dispatch: $.visible ?? Event::Visible !! Event::Invisible;
        }
    }
}

method cmd-close {
    return if $.closed;
    self.trace: "CLOSING";
    $!closed.keep(True);

    my @dismissed;
    self.for-children: {
        @dismissed.push: .dismissed;
        # Don't bother if child is already closing. Slightly relieve event flood.
        next if .closed;
        .close
    }
    self.dispatch: Event::Closing;
    Promise.allof(|@dismissed).then: {
        self.trace: "CHILDREN DISMISSED, DETACHING";
        $.detach;
    };
}

method flatten-canvas {
    self.trace: "Entering flatten-canvas, blocks count: ", $!flatten-blocks,
        "\ncanvas geom: ", ( $!canvas-geom // '*no yet*' ),
        "\npcanvas geom: ", ( $!pcanvas ?? $!pcanvas.geom !! "*not yet*" );
    if $!flatten-blocks > 0 {
        ++$!flatten-misses;
        return;
    }
    # No paints were done yet.
    return unless $!canvas-geom;
    unless $!pcanvas
        && $!pcanvas.w == $!canvas-geom.w
        && $!pcanvas.h == $!canvas-geom.h
    {
        self.trace: "(Re)create pcanvas using ", $!canvas-geom;
        $!pcanvas = self.create:
            Vikna::Canvas,
            w => $!canvas-geom.w,
            h => $!canvas-geom.h,
            :from( $!pcanvas // $!canvas );
    }
    $!pcanvas.invalidate: $_ for @!invalidations;
    self.trace: "self invalidations:\n", $!pcanvas.invalidations.map("  " ~*).join("\n");
    $!pcanvas.imprint: 0, 0, $!canvas, :!skip-empty;
    self.for-children: -> $child {
        # Newly added children might not have drawn yet. It's ok to skip 'em.
        next unless $child.visible;
        with %!child-by-id{$child.id}<canvas> {
            $!pcanvas.imprint: .geom.x, .geom.y, .canvas;
            $child.dispatch: Event::Updated,
                origin => self,
                geom => .geom;
        }
    }
    $!inv4parent-lock.protect: {
        $!inv-for-parent = @$!stash-parent-invs;
        $!stash-parent-invs = [];
    }
    # note self.name, " pick: ", $!pcanvas.pick(0,0) if self.name ~~ /Moveable/;
    with $.parent {
        self.trace: "Sending self canvas to ", .name;
        .child-canvas(self, $!canvas-geom.clone, $!pcanvas.clone, $!inv-for-parent) if $!inv-for-parent.elems > 0;
    }
    else {
        # If no parent then try sending to console.
        self.?print($!pcanvas);
        self.dispatch: Event::Updated, geom => $!canvas-geom;
    }
    $!pcanvas.clear-inv-rects;
    $.clear-invalidations;
    $!flatten-misses = 0;
}

method cmd-redraw( :$force? ) {
    return unless $.visible;
    if self.redraw-blocked {
        self.trace: "SKIP REDRAW UNTIL UNBLOCKED";
        self.redraw;
    }
    else {
        my Vikna::Canvas:D $canvas = $!canvas;
        self.trace: "CMD REDRAW: invalidations: ", @!invalidations.elems, "\n", @!invalidations.map("  . " ~ *.Str)
            .join("\n");
        if @!invalidations || $force {
            $canvas = self.begin-draw;
            self.draw(:$canvas);
            self.end-draw(:$canvas);
            $!canvas = $canvas;
            self.flatten-canvas;
            self.trace: "REDRAWN";
        }
    }
}

method cmd-refresh {
    $.flatten-canvas;
}

method cmd-childcanvas( ::?CLASS:D $child, Vikna::Rect:D $canvas-geom, Vikna::Canvas:D $canvas, @invalidations ) {
    self.trace: "CHILD CANVAS FROM ", $child.name, " AT { $canvas-geom } WITH ", +@invalidations, " INVALIDATIONS:\n",
        @invalidations.map({ "  " ~ $_ }).join("\n"),
        "\nMY GEOM: " ~ $.geom;
    %!child-by-id{$child.id}<canvas> = CanvasRecord.new: :$canvas, geom => $canvas-geom, :@invalidations;
    self.invalidate: $_ for @invalidations;
    $.flatten-canvas;
}

method cmd-setgeom(Int:D $x, Int:D $y, Int:D $w, Int:D $h, :$no-draw? ) {
    my $from;
    cas $!geom, {
        $from = $_;
        Vikna::Rect.new: :$x, :$y, :$w, :$h
    };
    self.trace: "Changing geom to ", $!geom;
    self.update-positions;
    self.trace: "Setgeom invalidations";
    self.add-inv-parent-rect: $from;
    self.invalidate;
    self.trace: "Setgeom children visibility";
    self.for-children: {
        .update-positions;
    }
    unless $no-draw {
        self.trace: "Setgeom redraw";
        $.redraw;
    }
    self.dispatch: Event::Changed::Geom, :$from, to => $!geom
    if    $from.x != $!geom.x || $from.y != $!geom.y
        || $from.w != $!geom.w || $from.h != $!geom.h;
}

method !change-attr( Event::Changed::Attr:U \evType, *%c ) {
    my $from = $!attr;
    $!attr = $!attr.dup: |%c;
    self.dispatch: evType, :$from, :to( $!attr ) unless $from.Profile eqv $!attr.Profile
}

method cmd-setcolor( BasicColor :$fg, BasicColor :$bg ) {
    return if ( !$fg || ( $!attr.fg eqv $fg ) ) && ( !$bg || ( $!attr.bg eqv $bg ) );
    self!change-attr(Event::Changed::Color, :$fg, :$bg)
}

method cmd-setstyle( Int $style ) {
    return if $!attr.style == $style;
    self!change-attr(Event::Changed::Style, :$style)
}

proto method cmd-setattr( | ) {*}
multi method cmd-setattr( Vikna::CAttr:D $attr ) {
    return if $!attr eqv $attr;
    self!change-attr(Event::Changed::Attr, |$attr.Profile);
}
multi method cmd-setattr( %profile ) {
    return if $!attr.Profile eqv %profile;
    self!change-attr(Event::Changed::Attr, |%profile)
}

method cmd-to-top( ::?CLASS:D $child ) {
    self!top-child-changed($.child-stratum( $child ));
    self.Vikna::Parent::to-top($child);
    self.invalidate: $child.geom;
    $.flatten-canvas;
    $child.dispatch: Event::ZOrder::Top;
    self.dispatch: Event::ZOrder::Child, :$child;
}

method cmd-nop( ) {}

proto method cmd-contains( ::?CLASS:D: Vikna::Coord:D $, | ) {*}
multi method cmd-contains( $obj, :$absolute! where *.so ) {
    $!abs-geom.contains($obj)
}
multi method cmd-contains( $obj ) {
    $!geom.contains($obj)
}

### Command senders ###

method add-child( ::?CLASS:D $child, ChildStrata $stratum = StMain, :$subscribe = True ) {
    self.send-command: Event::Cmd::AddChild, $child, $stratum, :$subscribe;
}

method remove-child( ::?CLASS:D $child ) {
    self.send-command: Event::Cmd::RemoveChild, $child;
}

method child-canvas( ::?CLASS:D $child, Vikna::Rect:D $canvas-geom, Vikna::Canvas:D $canvas, @invalidations ) {
    self.trace: "COMMAND child-canvas for child ", $child.name, " with ", +@invalidations, " invalidations";
    my $ev = self.send-command: Event::Cmd::ChildCanvas, $child, $canvas-geom, $canvas, @invalidations;
    # self.trace: "{$ev} {$canvas.w} x {$canvas.h}, invalidations:", @invalidations.map({ "\n  $_" });
    # $.redraw;
}

method redraw {
    self.trace: "SENDING REDRAW COMMAND";
    self.send-command: Event::Cmd::Redraw;
}

method to-top( ::?CLASS:D: ::?CLASS:D $child ) {
    self.send-command: Event::Cmd::To::Top, $child;
}

# Widgets willing to be raised to top upon request must override this method and take action.
method maybe-to-top {
    .maybe-to-top with $.parent;
}

method clear {
    self.send-command: Event::Cmd::Clear;
}

method resize( Dimension:D $w, Dimension:D $h ) {
    self.set-geom: $!geom.x, $!geom.y, $w, $h;
}

method move( Int:D $x, Int:D $y ) {
    self.set-geom: $x, $y, $!geom.w, $!geom.h;
}

proto method set-geom( ::?CLASS:D: | ) {*}
multi method set-geom( Int:D $x, Int:D $y, Dimension:D $w, Dimension:D $h ) {
    self.send-command: Event::Cmd::SetGeom, $x, $y, $w, $h;
}
multi method set-geom( Vikna::Rect:D $rect ) {
    self.send-command: Event::Cmd::SetGeom, .x, .y, .w, .h with $rect
}

method set-color( BasicColor :$fg, BasicColor :$bg ) {
    self.throw: X::BadColor, :which<foreground>, :color( $fg )
    unless Vikna::Color.is-valid($fg, :empty-ok, :throw);
    self.throw: X::BadColor, :which<background>, :color( $bg )
    unless Vikna::Color.is-valid($bg, :empty-ok, :throw);
    self.send-command: Event::Cmd::SetColor, :$fg, :$bg
}

multi method set-style( |c ) {
    self.send-command: Event::Cmd::SetStyle, to-style(|c)
}

proto method set-attr( | ) {*}
multi method set-attr( Vikna::CAttr:D $attr ) {
    self.send-command: Event::Cmd::SetAttr, $attr
}
multi method set-attr( *%c ) {
    self.send-command: Event::Cmd::SetAttr, %c
}

method set-bg-pattern( $pattern ) {
    self.send-command: Event::Cmd::SetBgPattern, $pattern;
}

method set-hidden( $hidden ) {
    self.send-command: Event::Cmd::SetHidden, ?$hidden;
}

method hide {
    self.send-command: Event::Cmd::SetHidden, True
}
method show {
    self.send-command: Event::Cmd::SetHidden, False
}

method set-invisible( $invisible ) {
    my $changed;
    cas $!invisible, {
        $changed = $_ ^^ $invisible;
        $invisible
    };
    if $changed {
        self.dispatch: $.visible ?? Event::Visible !! Event::Invisible;
    }
}

method sync-events( :$transitive ) {
    my @p;
    my $irresponsive = [];
    if $transitive {
        self.for-children: -> $chld {
            @p.push: %( widget => $chld, promise => $chld.nop[0].completed(:transitive));
        }
    }
    @p.push: %( widget => self, promise => $.nop.head.completed);
    self.trace: "LIST OF NOPS:\n", @p.map({ "  " ~ .<widget>.name ~ " p:" ~ .<promise>.^name }).join("\n");
    my $succeed = False;
    await Promise.anyof(
        Promise.in(30),
        self.flow: :name( 'SYNC EVENTS' ), {
            await eager @p.map({ $_<promise> });
            $succeed = True;
        }
        );
    unless $succeed {
        for @p {
            note $_<widget>.WHICH, " nop ", $_<promise>.?status.^name;
        }
        note $.name ~ " INTERNAL: { $transitive ?? "transitive " !! "" }sync-events timeout exceeded";
        self.panic: X::AdHoc.new: payload => $
            .name ~ " INTERNAL: { $transitive ?? "transitive " !! "" }sync-events timeout exceeded";
    }
}

method nop {
    # note self.name, " NOP";
    self.send-command: Event::Cmd::Nop
}

method contains( Vikna::Coord:D $obj, :$absolute? ) {
    self.send-command: Event::Cmd::Contains, $obj, :$absolute
}

### State methods ###

method visible {
    !( $!hidden || $!invisible || $.closed )
}

method closed {
    !( $!closed.status ~~ Planned )
}

### Utility methods ###

method update-positions( :$transitive? ) {
    if $.parent {
        my $parent-geom = $.parent.geom;
        my $parent-viewport = $.parent.viewport;
        my $parent-abs = $.parent.abs-geom;
        my $gr = $!geom;
        $!viewport = $!geom.clip($parent-viewport).relative-to($!geom);
        $!abs-geom = $!geom.absolute($parent-abs);
        $!abs-viewport = $!viewport.absolute($!abs-geom);
        # self.trace: "PARENT GEOMS:",
        #          "\n  geom    : ", $parent-geom,
        #          "\n  abs     : ", $parent-abs,
        #          "\n  viewport: ", $parent-viewport,
        #          "\nOWN GEOMS:",
        #          "\n  geom    : ", $!geom,
        #          "\n  abs     : ", $!abs-geom,
        #          "\n  viewport: ", $!viewport,
        #          ;
    }
    else {
        $!abs-geom = $!abs-viewport = $!geom;
        $!viewport = Vikna::Rect.new: 0, 0, $!geom.w, $!geom.h;
    }
    if $transitive {
        self.for-children: {
            .update-positions(:transitive)
        }
    }
    self.set-invisible: not ( $!viewport.w && $!viewport.h );
}

method add-inv-parent-rect( Vikna::Rect:D $rect ) {
    if $.parent {
        self.trace: "ADD TO STASH OF PARENT INVS: ", ~$rect;
        $!inv4parent-lock.protect: {
            $!stash-parent-invs.push: $rect
        }
    }
}

method add-inv-rect( Vikna::Rect:D $rect ) {
    my $vrect = $rect.clip($!viewport);
    $!inv-lock.protect: {
        @!invalidations.push: $vrect;
    }
    self.add-inv-parent-rect: $vrect.absolute($!geom);
    $vrect
}

method clear-invalidations {
    $!inv-lock.protect: {
        @!invalidations = [];
    }
}

proto method invalidate( | ) {*}

multi method invalidate( Vikna::Rect:D $rect ) {
    self.trace: "INVALIDATE ", ~$rect, "\n -> ", $.parent.WHICH, " as ", $rect.absolute($.geom);
    self.add-inv-rect: $rect
}

multi method invalidate( UInt:D $x, UInt:D $y, Dimension $w, Dimension $h ) {
    self.invalidate: Vikna::Rect.new(:$x, :$y, :$w, :$h)
}

multi method invalidate( UInt:D :$x, UInt:D :$y, Dimension :$w, Dimension :$h ) {
    self.invalidate: Vikna::Rect.new(:$x, :$y, :$w, :$h)
}

multi method invalidate( @invalidations ) {
    self.invalidate: $_ for @invalidations
}

multi method invalidate( ) {
    self.invalidate: Vikna::Rect.new(:0x, :0y, :$.w, :$.h);
}

method begin-draw( Vikna::Canvas $canvas? is copy --> Vikna::Canvas ) {
    $!canvas-geom = $!geom.clone;
    $canvas //= self.create:
        Vikna::Canvas,
        :$.w, :$.h,
        :$!inv-mark-color,
        |( $!auto-clear ?? (  ) !! :from( $!canvas ) );
    self.invalidate if $!auto-clear;
    self.trace: "begin-draw canvas (auto-clear:{ $!auto-clear }): ", $canvas.WHICH, " ", $canvas.w, " x ", $canvas.h;

    for @!invalidations {
        $canvas.invalidate: $_
    }

    $canvas
}

method end-draw( :$canvas! ) {
    self.trace: "END DRAW";
    # self.clear-invalidations;
}

method redraw-block {
    ++⚛$!redraw-blocks;
    self.trace: "REDRAW BLOCK, block count: ", $!redraw-blocks;
    self.for-children: { .redraw-block };
}

method redraw-unblock {
    self.for-children: { .redraw-unblock };
    given --⚛$!redraw-blocks {
        when 0 {
            self!release-redraw-event;
        }
        when * < 0 {
            self.throw: X::OverUnblock, :count( .abs ), :what<redraw>;
        }
    }
    self.trace: "REDRAW UNBLOCK, block count: ", $!redraw-blocks;
}

method redraw-blocked {
    ?$!redraw-blocks
}

method redraw-hold( &code, |c ) {
    $.redraw-block;
    LEAVE $.redraw-unblock;
    &code( |c )
}

# Contrary to redraw, flattenning must not be auto-blocked on children.
method flatten-block {
    ++⚛$!flatten-blocks;
    self.trace: "Flattening block: ", $!flatten-blocks;
}

# Don't auto-flatten when counter is zeroed.
method flatten-unblock {
    with --⚛$!flatten-blocks {
        if $_ < 0 {
            self.throw: X::OverUnblock, :count( $!flatten-blocks ), :what( 'canvas flattenning' )
        }
        elsif $_ == 0 && $!flatten-misses {
            if $*VIKNA-EVQ-OWNER && $*VIKNA-EVQ-OWNER === self {
                $.flatten-canvas;
            }
            else {
                self.send-command: Event::Cmd::Refresh;
            }
        }
    }
    self.trace: "Flattening un-block: ", $!flatten-blocks;
}

method flatten-hold( &code, |c ) {
    $.flatten-block;
    LEAVE $.flatten-unblock;
    &code( |c )
}

method draw( Vikna::Canvas:D :$canvas ) {
    self.draw-background(:$canvas);
}

method draw-background( Vikna::Canvas:D :$canvas ) {
    if $.attr.pattern {
        self.trace: "DRAWING BACKGROUND, pattern: ‘{ $.attr.pattern }’";
        # Don't use $!attr or it breaks Focusable.
        my $bgpat = $.attr.pattern;
        my $back-row = ( $bgpat x ( $.w.Num / $bgpat.chars ).ceiling );
        my %attr-profile = $.attr.Profile;
        for ^$.h -> $row {
            $canvas.imprint(0, $row, $back-row, |%attr-profile);
        }
    }
}

proto method cursor( | ) {*}
multi method cursor( Vikna::Point:D $pos ) {
    $.app.screen.move-cursor: $pos.absolute($!abs-geom);
}
multi method cursor( Int:D $x, Int:D $y ) {
    self.cursor: Vikna::Point.new($x, $y);
}

method hide-cursor {
    $.app.desktop.hide-cursor;
}

method show-cursor {
    $.app.desktop.show-cursor;
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
        self.trace: "Held redraw event: " ~ $rh;
        self.re-dispatch: $rh, :priority( PrioReleased ) unless $.closed;
    }
}

method !hold-redraw-event( $ev ) {
    my $drop;
    # cas block can be ran more than once. Thus, no irreversible actions should be done and $drop flag must be set on
    # both 'if' branches for consistency.
    cas $!redraw-on-hold, {
        if $_ {
            self.trace: "ALREADY HOLDING ", $_;
            $drop = True;
            $_
        }
        else {
            self.trace: "RECORDING FOR HOLD ", $ev;
            $drop = False;
            $ev
        }
    };
    self.drop-event: $ev if $drop;
}

# Filters are protected from concurrency by EventHandling
multi method event-filter( Event::Cmd::Redraw:D $ev ) {
    self.trace: "WIDGET EV FILTER: ", $ev, ", redraw blocks: $!redraw-blocks";
    if $!redraw-blocks == 0 && $!redraws.try_acquire {
        # There is no current redraws, we just proceed further but first make sure we release the resource when done.
        $ev.completed.then: {
            self.flow: :name( 'REDRAW RELEASE' ), {
                self.trace: "RELEASING REDRAW SEMAPHORE";
                $!redraws.release;
                self!release-redraw-event;
            }
        };
        [$ev]
    }
    else {
        # There is another redraw active.
        self.trace: "PUT ", $ev, " on hold";
        self!hold-redraw-event: $ev;
        # This event won't go any further...
        []
    }
}

method next-sibling( :$loop = False, :$on-strata = False ) {
    return Nil unless $!parent;
    .children-protect: { .next-to: self, :$loop, :$on-strata } with $!parent
}

method prev-sibling( :$loop = False, :$on-strata = False ) {
    return Nil unless $!parent;
    .children-protect: { .next-to: self, :reverse, :$loop, :$on-strata } with $!parent
}

method close {
    self.send-command: Event::Cmd::Close;
}

method quit {
    if $.app && $.app.desktop {
        $.app.desktop.quit;
    }
    else {
        $.close;
    }
}

method detach {
    with $.parent {
        self.trace: "DETACHING FROM PARENT ", ( .?name // .WHICH );
        .remove-child: self;
    }
    else {
        self.trace: "DETACHING, NO PARENT";
        self.dispatch: Event::Detached, :child( self ), :parent( self );
    }
}

method shutdown {
    self.stop-event-handling.then: {
        $!dismissed.keep(True);
    }
}

method panic( $cause ) {
    my $bail-out = True;
    if $.app && $.app.desktop {
        $.app.desktop.dismissed.then: { $bail-out = False; };
        await Promise.anyof(
            Promise.in(10),
            start $.app.panic($cause, :object( self ))
            );
    }
    else {
        nextsame;
    }
    exit 1 if $bail-out;
}

proto method get-child( ::?CLASS:D: | ) {*}
multi method get-child( Str:D $name --> Vikna::Widget ) {
    %!child-by-name{$name}:exists ?? %!child-by-id{%!child-by-name{$name}}<child> !! Nil
}
multi method get-child( Int:D $id --> Vikna::Widget ) {
    %!child-by-id{$id}:exists ?? %!child-by-id{$id}<child> !! Nil
}

proto method AT-KEY( | ) {*}
multi method AT-KEY( ::?CLASS:D: Str:D $wname ) {
    %!child-by-name{$wname} ?? %!child-by-id{%!child-by-name{$wname}}<child> !! Nil
}
multi method AT-KEY( ::?CLASS:D: Int $id ) {
    %!child-by-id{$id}<child>
}
multi method AT-KEY( ::?CLASS:U: | ) {
    Nil
}

proto method EXISTS-KEY( | ) {*}
multi method EXISTS-KEY( ::?CLASS:D: Str:D $wname ) {
    %!child-by-name{$wname}:exists
}
multi method EXISTS-KEY( ::?CLASS:D: Int:D $id ) {
    %!child-by-id{$id}:exists
}
multi method EXISTS-KEY( ::?CLASS:U: | ) {
    False
}

proto method DELETE-KEY( | ) {*}
multi method DELETE-KEY( ::?CLASS:D: Str:D $wname ) {
    self.remove-child: $_ with $.get-child( $wname );
}
multi method DELETE-KEY( ::?CLASS:D: Int:D $id ) {
    self.remove-child: $_ with $.get-child( $id );
}

method Bool {
    self.defined && $!closed.status ~~ Planned
}

method Str {
    $.name
}

method gist {
    $.id ~ ":" ~ $.name
}
