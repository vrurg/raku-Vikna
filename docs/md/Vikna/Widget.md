NAME
====



`Vikna::Widget` - the base of all widgets

DESCRIPTION
===========



...

Flattening Canvas
-----------------

After a widget has drawn itself Vikna takes a number of step to ensure it is imprinted correctly on its parent and, eventually, on the screen. The process is called *flattening* because figuratively it could be described as if Z-order of children canvas is flattened down into parent's canvas. Here is how this happens.

Many good stories starts from the end. This one does it too. Let's skip all preceding steps and say that widget sends it's ready canvas (BTW, it is internally called imPrinted canvas and abbreviated to just `pcanvas`) and all current invalidations (converted into parent's coordinate system) to the parent. At this point widget's work is over and it clears all invalidations. The next cycle starts now.

Meanwhile, the parent receives `Event::Cmd::ChildCanvas` and records the received object in its local registry. The invalidations which came with the command event are appended to the list of local invalidations. This is where the story starts because the parent immediately initiates the *flattening*. From this moment on we stop using term *parent* and using just *widget* again.

The first step is checking if the flattening is not blocked for a reason. If so, we increase flatten miss counter and leave. When all blockers are done, the framework checks the counter and initiates immediate flattening.

Now, we need to prepare `pcanvas`. Normally, if widget dimensions are not changed, `pcanvas` is preserved across flattening cycles and only updated using invalidations. It somewhat speeds up the flattening process by avoiding extra object allocations and copying of full canvas content each time, especially if only tiny bits of widget are updated.

If there is no block installed, then currently active invalidations are applied to `pcanvas`. Then widget imprints own canvas on `pcanvas` and all collected children canvas from the local registry unless a child is invisible. It means that if a child was created and attached but never sent its canvas up to the parent – it would never be displayed.

Children are also get notified of their canvas is used with `Event::Updated`.

Once again, note that imprinting will only change the areas of the widget which were invalidated either by the widget itself or by mapped invalidations from children. A good example of how it works would be the following scheme:

    ...............
    .. Label ......
    ...............

The dots represent a parent widget with a [`Vikna::Label`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Label.md) child attached. Then, say, we change the label text. No other changes were done. Then the only area on `pcanvas` which will be affected by flattening will be the one-line rectangle at `(x:2, y:1, w:7, h:1)` granted that text change doesn't change label's dimentions. If the parent widget is really big this optimization would save us a whole lot copying over! Moreover, the invalidation will then be propagated further upstream resulting in the same little changes done in all parents up until the desktop and screen themselve.

At this point flattening down of canvas is almost done. If widget has a parent, it invokes `child-canvas` command method on it with `pcanvas` and mapped invalidations.

If the widget is the top one (i.e. the desktop) then it calls command method `print` with `pcanvas`. `Event::Updated` is then sent to self as if our parent notified us of imprint taken place.

And so, the story closes the cycle...

ATTRIBUTES
==========



### `L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md>:D $.geom`

Widget geometry in its parent coordinate system.

### `L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> $.viewport`

Visible part of the widget in its parent coordinate system. To be more precise, this is widget's `$.geom` clipped by parent's viewport. In the scheme below 1 is our viewport area. It might be even smaller if the parent itself isn't fully visible.

    +---------+

    +---- Parent ----+   |
    |          |  1  | 2 |
    |          +-----|---+
    +----------------+

### `L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> $.abs-geom`

Widget geometry in absolute coordinate system. By *absolute* we take the screen, but because the desktop object is assumed to occupy the whole screen, all absolute coordinates are taken relatively to desktop.

### `L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md> $.abs-viewport`

Similar to `$.abs-geom`, but for `$.viewport`.

### `L<Vikna::WAttr|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md>:D $.attr`

Widget default attributes.

### `Bool:D $.auto-clear`

If *True* then every new draw operation starts with a fresh canvas. Otherwise new canvas get its content from the last draw operation.

### `Bool:D $.hidden`

If *True* then widget is intentionally hidden on its parent.

### `Bool:D $.invisible`

If *True* then widget is outside of parent's viewport and thus not visible on the screen. The difference with `$.hidden` attribute is that the latter is set intentionally, while this attribute is a result of calculations of widget position.

### `L<Vikna::Canvas|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md> $.canvas`

Widget canvas after the last redraw operation.

### `Promise:D $.dismissed`

This promise is kept with *True* when widget has shutdown. In particular, its event loop has been stopped.

### `@.invalidations`

List of invalidation rectangles. Is used for the next redraw operation and cleared after flattened down canvas were sent over to the parent.

METHODS
=======



### `submethod profile-checkin(%profile, $constructor, %, %)`

The default widget profile checkin is responsible for the following operations:

  * it converts `x`, `y`, `w`, `h` profile keys into `geom` by creating a new [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md) instance unless `geom` is defined explicitly

  * it converts `fg`, `bg`, `style`, and `pattern` profile keys into `attr` by creating a new [`Vikna::WAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md) instance

All mentioned above source keys are unconditionally deleted from `%profile`.

### `create-child(Vikna::Widget:U \widgetType, ChildStrata $stratum = StMain, *%p)`

Create a new widget child. The child is created detached and `Event::Init` is dispatched on it instantly. Then it is added to the widget with `add-child` method.

Returns the child object.

### `subscribe-to-child(Vikna::Widget:D $child)`

Method subscribes self to child events and passes them to widget's `child-event` handler method.

### `multi route-event(Event::Spreadable:D $ev)`

Re-dispatches `$ev` to child widgets.

### `multi child-event(Event:D)`

Proto defined to handle children events if subscribed to a child. By default does nothing.

### `subscription-event(Event:D $ev)`

Proto defined to handle any other subscription events. By default does nothing. See [`Vikna::EventHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventHandling.md) role.

### `flatten-canvas()`

Normally one doesn't need this method except special care is required to guarantee correct imprinting of a object on its parent.

See [Canvas Flattening](#Canvas Flattening) section above.

Command Methods
---------------

This is a group of methods which sends command events to the widget. Normally they're just shortcuts for [`Event::CommandHandling`](https://modules.raku.org/dist/Event::CommandHandling) `send-command` method. Because this is what user must interact with, `cmd-*` methods are not documented. Their specifics will be elaborated on in description of command methods.

### `add-child(Vikna::Widget:D $child, ChildStrata $stratum = StMaian, :$subscribe = True)`

`Event::Cmd::AddChild`. Adds a new child to the widget. This includes subscribtion to child events if `$subscribe` is *True*.

Upon successfull addition `Event::Attached` is dipatched on both the child and self. If the added child becomes the topmost one on strata, `Event::ZOrder::Top` is dispatched on the child and `Event::ZOrder::Child` on self.

### `remove-child($child)`

`Event::Cmd::RemoveChild`. Removes a child from the widget children list. Emits `Event::Detached` on the child.

A child could be removed from its parent for two reasons: either it is closing or it is switching to another parent. The command considers both situation. If the child is closing, then the widget awaits until it becomes `$.dismissed` before finalizing the removal. Otherfile finalization takes place immediately.

The finalization of child removal does:

  * dispatches `Event::Detached` on self

  * redraws the widget to update the area previously occupied by the child.

Corresponding `Event::ZOrder::*` events are dispatched if necessary.

### `child-canvas(Vikna::Widget:D $child, Vikna::Rect:D $canvas-geom, Vikna::Canvas::D $canvas, @invlidations)`

`Event::Cmd::ChildCanvas`. Register updated child canvas on the widget. Must not be used by user code normally.

Part of the [Canvas Flattening](#Canvas Flattening) process. A child sends this command every time its own `pcanvas` is updated.

### `redraw()`

`Event::Cmd::Redraw`. Request the widget to redraw itself. The action might not happen in on of the cases:

  * when widget is `$.invisible`

  * if redraws are blocked on the widget (see `redraw-block` method)

  * if the widget doesn't have any invalidations registered

When drawing is possible, new canvas is created by `begin-draw` method and passed to widget method `draw`. When it's done `end-draw` is invoked with the same canvas object which is then set as widget's `$.canvas`. At the end widget flattens canvas, as described in [Canvas Flattening](#Canvas Flattening).

### `to-top(Vikna::Widget:D $child)`

`Event::Cmd::To::Top`. Sends a `$child` to the top of Z-order within it's stratum. Then invalidates the rectangle occupied by the child and flattens canvas.

`Event::ZOrder::Top` is dispatched on the child, `Event::ZOrder::Child` is dispatched on self.

### `maybe-to-top()`

Normally does nothing. It is used by [`Vikna::Elevatable`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Elevatable.md) role to signal to a widget it is applied to there is an event happened to which the widget can respond by elevating itself to the top of Z-order.

For example see [`Vikna::Window`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Window.md).

### `clear()`

`Event::Cmd::Clear`. The command is bypassed down to widget children too. Then fully invalidates and redraws the widget.

### `resize($w, $h)`

Shortcut for `set-geom` method with preserved widget coordinates.

### `move($x, $y)`

Shortcut for `set-geom` method with preserved widget dimensions

### `multi set-geom($x, $y, $w, $h)`

### `multi set-geom(Vikna::Rect:D $geom)`

`Event::Cmd::SetGeom`. Method changes widget geometry on its parent. It has the following side effects:

  * widget position information is updated by `update-positions` method.

  * widget is invalidated as a whole

  * the old widget rectangle is invalidated on its parent

  * position information is updated on children

  * widget redraw is initiated

`Event::Changed::Geom` is dispatched on self if the requested geometry differs from the previous one.

### `close()`

`Event::Cmd::Close`. Close the widget.

Firs, the command is bypassed down to the widget children. `Event::Closing` is dispatched on self. Then the widget awaits for all children to dismiss and when they have detaches itself from the parent. Then see `detach` method description.

### `quit()`

Shortcut for quitting the whole application. A child widget invokes `quit` method on the desktop. The desktop closes itself.

### `detach()`

If the widget has a parent then invokes `remove-child` on it for self. Otherwise we're the desktop widget and only dispatch `Event::Detached` on self with event `child` attribute set to `self` too.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Object`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Object.md), [`Vikna::Parent`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Parent.md), [`Vikna::Child`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Child.md), [`Vikna::EventHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventHandling.md), [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CommandHandling.md), [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md), [`Vikna::Events`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Events.md), [`Vikna::Color`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Coloe.md), [`Vikna::Canvas`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md), [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Utils.md), [`Vikna::WAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md), [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

### has Vikna::Rect $.viewport

Visible part of the widget relative to the parent.

### has Vikna::Rect $.abs-geom

Rectange in absolute coordinates of the top widget (desktop)

### has Vikna::Rect $.abs-viewport

Visible rectange of the vidget in it's parent in absolute coords.

