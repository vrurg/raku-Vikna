NAME
====



`Vikna::Events` - core event classes and roles

SYNOPSIS
========



    class Event::Foo is Event::Informative { }
    class Event::Cmd::Bar is Event::Command { }

DESCRIPTION
===========



Event is an instance of the class `Event`.

Events (here and further by referring to an event we refer to its class unless stated otherwise) can be grouped by few categories. First, by their type:

  * informative are events which only informs about a state change, or an action took place, or whatever else

  * commands are events containing a command to be executed; see [`Event::CommandHandling`](https://modules.raku.org/dist/Event::CommandHandling) for additional details

  * input events something produced by external devices either virtual or physical

  * output are events which send output to external devices

These in turn could split into subcategories.

Another event grouping category is event priority. These are (in the order from lower to higher):

  * idle

  * default

  * command

  * released

  * output

  * input

  * immediate

Priorities are defined by `EventPriority` enum with the following values:

  * `PrioIdle`

  * `PrioDefault`

  * `PrioCommand`

  * `PrioReleased`

  * `PrioOut`

  * `PrioIn`

  * `PrioImmediate`

While there is hope that priority names are self-explanatory, *released* is likely needing a few words about.

There is a situation possible where an event is considered to be not on time and gets postponed for later. An example of such situation is described in *Redraw Hold* section of [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Widget.md). In this situation it might be considered useful to dispatched the event with slightly higher priority to handle it as soon as possible. This is what `PrioReleased` is useful for. In the case of *redraw holding* it allows the redraw command to be processed before any other command queued making it very likely for the redraw to happen almost right away after the previos one is finished.

Next sections are descriptions of classes and roles.

`Event`
=======

Attributes
----------

### `$.id`

Event unique ID. The uniqueness is guaranteed to be process-wide. This also means that `dup`-ed events will have different IDs (but not `clone`-d).

### `$.origin`

What object has created the event. By default is the same as `$.dispatcher`.

### `$.dispatcher`

The object which is dispatching an event. It is possible that an event is originated by one object but dispatched by another. For example, this is what happens to keyboard or mouse input events.

### `$.cleared`

If set to *True* then event has been taken care of and in some cases must not be handled anywhere else.

**Note** the final semantics of this attribute is not really defined yet.

### `$.priority`

Event default priority. To set it a sub-class can defined a method `default-priority` which must return one of `EventPriority` enums.

Methods
-------

### `dup(*%p)`

Duplicates an event object giving the copy a new ID.

### `clear()`

Clears the event (see `$.cleared` above).

### `to-method-name(Str:D $prefix)`

Makes a method name from the event class name by cutting out everything up to and including `Event::`. The remaining string is modified by replacing *"::"* with *"-"* and lowercasing other parts. `$prefix` is prepended to the beginning of the resulting string with *"-"* char unless the prefix already ends with it.

### `Str()`

Stringifies the event object.

Roles `Event::Prio::Idle`, `Event::Prio::Default`, `Event::Prio::Command`, `Event::Prio::Released`, `Event::Prio::In`, `Event::Prio::Out`
=========================================================================================================================================

The roles define `default-priority` method with corresponding `Prio*` enum value returned.

Role `Event::Changish[::T \type = Any]`
=======================================

The role define a subcategory of events reporting about a state change. It defines attributes `$.from` and `$.to` of type `T`.

Role `Event::Focusing`
======================

Events consuming this role are routed using the rules of focused dispatching, as implemented by [`Vikna::Focusable`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Focusable.md).

Role `Event::ZOrderish`
=======================

Events of this subcategory are expected to carry information about Z-order changes.

Role `Event::Spreadable`
========================

Events of this subcategory are automatically spreaded to children. For example, `Event::Quit` is sent down to all widgets.

Role `Event::Geomish`
=====================

Subcategory of events bearing information about a rectangle. Defines single attribute `$.geom` (aliased as `$.to`) of [`Event::Rect:D`](https://modules.raku.org/dist/Event::Rect).

Role `Event::Transformish`
==========================

Does `Event::Geomish`. Subcategory of geomish events containing information about a transformation of some kind where state is changing *from* one rectangle *to* another. Adds `$.from` attribute of [`Vikna::Rect:D`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Rect.md).

Role `Event::Positionish`
=========================

Subcategory of events bearing information about some 2D position. Defines attribute `$.at` of [`Vikna::Point:D`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Point.md) and handling methods ro-accessors `x` and `y`.

Role `Event::Vectorish`
=======================

Subcategory of events defining a vector-like information with *from* and *to* positions. Correspondingly, defines attributes `$.from` and `$.to` of [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Point.md).

Role `Event::Pointer::Elevatish`
================================

Subcategory of events which might move a widget to the top of Z-order.

Role `Event::Childing`
======================

Subcategory of events bearing information about a [`Vikna::Child`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Child.md). Defines attribute `$.child`.

Role `Event::Parentish`
=======================

Subcategory of events bearing information about a [`Vikna::Parent`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Parent.md). Defines attribute `$.parent`.

Role `Event::Relational`
========================

Does `Event::Childish` and `Event::Parentish`. Events with information about both parent and child objects.

`Event::Informative`
====================

Is `Event`, does `Event::Prio::Default`. Events of this class are only informing about something.

`Event::Command`
================

Is `Event`, does `Event::Prio::Command`.

Pass a command to an event handler. Support provided by [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/CommandHandling.md).

Attributes
----------

### [`Promise:D`](https://docs.raku.org/type/Promise) `$.completed`

This promise is kept when a command is completed with return value of the command method.

### `$.completed-at`

Will contain a backtrace of invocation of event method `complete`.

### [`Capture:D`](https://docs.raku.org/type/Capture) `$.args`

Arguments to invoke the command method with. For example:

    method resize(Int:D $w, Int:D $h) {
        self.send-event: Event::Cmd::Resize, :args(\($w, $h));
    }
    method cmd-resize($w, $h) { ... }

There is a shortcut method `send-command` defined in [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/CommandHandling.md).

Methods
-------

### `complete($rc)`

Sets command event completion status by keeping `$.completed` with $rc and recording the backtrace at the point where `complete` is invoked.

`Event::Input`
==============

Is `Event`, does `Event::Prio::Input`. Category of input events.

`Event::Output`
===============

Is `Event`, does `Event::Prio::Output`. Category of output events.

`Event::Kbd`
============

Is `Event::Input`, does `Event::Focusish`. Category of keyboard events.

Attributes
----------

### `$.raw`

Raw key data

### `$.char`

A character representing the key

### [`Set:D`](https://docs.raku.org/type/Set) `$.modifiers`

Modifier keys. See `ModifierKeys` enum in [`Vikna::Dev::Kbd`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Dev/Kbd.md).

Role `Event::Rbd::Partial`
==========================

Keyboard events of this subcategory are not about a key press.

Role `Event::Cmd::Complete`
===========================

Keyboard events of this subcategory are reporting about a key press.

`Event::Pointer`
================

Is `Event::Input`, does `Event::Positionish`. Events of this category are informing about a pointer device events. Define a single abstract method `kind` which has to be overriden by children and return a string returning the pointer device name.

`Event::Mouse`
==============

Is `Event::Pointer`. All mouse events are inheriting from this class.

Attributes
----------

### `Int:D $.button`

A number of the mouse button.

### `@.buttons`

All buttons presses at the time of event happened.

### [`Set`](https://docs.raku.org/type/Set) `$.modifiers`

Keyboard modifier keys active at the time of event. See `$.modifiers` of `Event::Kbd` above.

### [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Point.md) `$.prev`

Previous mouse position. The first ever mouse event will have it undefined.

Methods
-------

### `dup(*%p)`

Duplicates the event object.

### `kind()`

Returns string *'mouse'*.

`Event::Cmd::*` Classes
=======================

Is `Event::Command`. Command events are strictly bound to the command methods and thus documented as a part of method description. The only thing we would elaborate on here are priorities of some commands:

  * `Event::Cmd::ChildCanvas` has *output* priority

  * `Event::Cmd::Nop` is *default*.

  * `Event::Cmd::Print::String` is *output*

  * `Event::Cmd::Refresh` has *released* priority. This command is internal and issued by `flatten-unblock` method when it finds that all blocks are removed and there were missed requests for flattening.

`Event::Cmd::Inquiry`
=====================

This is a subcategory of commands for implementing state-safe requests to widgets. For now the only example of such inquiry command is [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Widget.md) method `contains`.

This feature is even more experimental than Vikna itself and might be gone in the future.

`Event::Init`
=============

Is `Event::Informative`, *immediate* priority. This is the first event a widget receives right after object creation. Dispatched by [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Widget.md) `create-child` method.

`Event::Ready`
==============

Is `Event::Informative`, *immediate* priority. Dispatched after widget is attached to its parent.

`Event::Attached`, `Event::Detached`
====================================

Is `Event::Informative`, does `Event::Relational`. Inform about a child being added to or removed from parent child list.

`Event::Quit`
=============

Is `Event::Informative`, does `Event::Spreadable`, *immediate* priority. Notifies about the application is about to quit giving a widget time to shutdown accordingly.

`Event::Idle`
=============

Is `Event::Informative`, *idle* priority. Not used internally but can be utilized by user code to implement actions done when a widget has no other events to process.

`Event::Changed::Attr`
======================

Is `Event::Informative`, does `Event::Changish[Vikna::CAttr]`. Notifies about widget attribtes change.

`Event::Changed::Color`
=======================

Is `Event::Changed::Attr`. Only a color has changed.

`Event::Changed::Style`
=======================

Is `Event::Changed::Attr`. Only style has changed.

`Event::Changed::Title`
=======================

Is `Event::Informative`, does `Event::Changish[Str]`. [`Vikna::Window`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Window.md) title changed.

`Event::Changed::Text`
======================

Is `Event::Informative`, does `Event::Changish[Str]`. Text has changed. Currently is only used by [`Vikna::Label`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Label.md).

`Event::Changed::BgPattern`
===========================

Is `Event::Informative`, does `Event::Changish[Str]`. Widget background patter changed.

`Event::Changed::Geom`
======================

Is `Event::Informative`, does `Event::Transformish`. Widget position/dimensions changed.

`Event::InitDone`
=================

Is `Event::Informative`. Widget initialization stage is fully completed, including the first redraw.

`Event::Redrawn`
================

Is `Event::Informative`. Widget redrawn operation completed.

`Event::Flattened`
==================

Is `Event::Informative`. Widget canvas flattening completed.

`Event::Hide`, `Event::Show`
============================

Is `Event::Informative`. Request to hide or show was processed.

`Event::Visible`, `Event::Invisible`
====================================

Is `Event::Informative`. Dispatched only if widget visibility status changed either explicitly with `show`/`hide` method calls, or implicitly if a widget is gone out of a viewport.

`Event::Focus::Take`, `Event::Focus::Lost`, `Event::Focus::In`, `Event::Focus::Out`
===================================================================================

Is `Event::Informative`. See [`Vikna::Focusable`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Focusable.md) for more details.

`Event::Closing`
================

Is `Event::Informative`. Close request was received.

`Event::ZOrder::Top`, `Event::ZOrder::Bottom`, `Event::ZOrder::Middle`
======================================================================

Is `Event::Informative`, does `Event::ZOrderish`. Informs a widget about changes in its Z-order positions. `Event::ZOrder::Middle` dispatched only when positioning involves top or bottom positions. For example, when a widget was atop and shifted down by another sibling elevated.

`Event::ZOrder::Child`
======================

Is `Event::Informative`, does `Event::ZOrderish`, `Event::Childish`. Widget is informed that Z-order position of one of its children has changed. Similarly to `Event::ZOrder::Middle` only dispatched if its about top- or bottommost positions.

`Event::Updated`
================

Is `Event::Informative`. Dispatched by parent to a child when child canvas are applied by flattening. Contains `$.geom` attribute which is a copy of the canvas geometry.

`Event::Scroll::Position`
=========================

Is `Event::Informative`, does `Event::Vectorish`. See [`Vikna::Scrollable`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Scrollable.md).

`Event::Scroll::Area`
=====================

Is `Event::Informative`, does `Event::Transformish`. See [`Vikna::TextScroll`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/TextScroll.md).

`Event::TextScroll::BufChange`
==============================

Is `Event::Informative`, does `Event::Changish[Int:D]`. See [`Vikna::TextScroll`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/TextScroll.md).

`Event::Kbd::Dow`, `Event::Kbd::Up`
===================================

Is `Event::Kbd`, does `Event::Kbd::Partial`. Key down/up events are signaling the begin and the end of key press event. Might not be supported by all platforms.

`Event::Kbd::Press`
===================

Is `Event::Kbd`, does `Event::Kbd::Complete`. Single key press event.

`Event::Kbd::Control`
=====================

Is `Event::Kbd`, does `Event::Kbd::Complete`. A control key press. See `ControlKeys` in [`Vikna::Dev::Kbd`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Dev/Kbd.md).

`Event::Mouse::Move`
====================

Is `Event::Mouse`. Move pointer position change.

`Event::Mouse::Button`
======================

Is `Event::Mouse`. Mouse button event subcategory.

`Event::Mouse::Press`, `Event::Mouse::Release`, `Event::Mouse::Click`, `Event::Mouse::DoubleClick`
==================================================================================================

Is `Event::Mouse::Button`. `Event::Mouse::Click` also does `Event::Pointer::Elevatish`. Press and release are simple button events. Click is a result of a fast enough press-release pair of events. Double click is a result of fast enough two click events. See more in [`Event::Dev::Mouse`](https://modules.raku.org/dist/Event::Dev::Mouse).

Role `Event::Mouse::Transition`.
================================

Does `Event::Positionish`. A subcategory of events reporting about events resulting from mouse movement.

`Event::Mouse::Enter`, `Event::Mouse::Leave`
============================================

Is `Event::Input`, does `Event::Mouse::Transition`. Mouse entered or left widget premises.

`Event::Pointer::OwnerChange`
=============================

Is `Event::Input`, does `Event::Changish`, `Event::Positionish`. Reports a parent about mouse pointer leaving one of its children. See [`Vikna::PointerTarget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/PointerTarget.md).

`Event::Button`
===============

Is `Event::Informative`. A subcategory of events used by [`Vikna::Button`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Button.md) widget.

`Event::Button::Down`, `Event::Button::Up`, `Event::Button::Press`
==================================================================

Is `Event::Button`. Stages of clicking a button. Press is a result of down/up pair of events.

`Event::Button::Ok`, `Event::Button::Cancel`
============================================

Is `Event::Button::Press`. Predefined shortcuts for the most typical kinds of buttons.

`Event::Screen::FocusIn`, `Event::Screen::FocusOut`, `Event::Screen::PasteStart`, `Event::Screen::PasteEnd`
===========================================================================================================

Is `Event::Input`. Translation of corresponding ANSI-terminal events. May or may not be supported by other platforms.

`Event::Screen::Ready`
======================

Is `Event::Informative`. Reported by a screen when it finishes a block operation and is ready for the next one.

`Event::Screen::Geom`
=====================

Is `Event::Informative`, does `Event::Transofrmish`, `Event::Spreadable`. Reports screen dimensions change. Has *immediate* priority.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md), [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Rect.md), [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Point.md), [`Vikna::Child`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Child.md), [`Vikna::Parent`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Parent.md), [`Vikna::Dev::Kbd`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Dev/Kbd.md), [`Vikna::CAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/CAttr.md), [`Vikna::X`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/X.md), [`Vikna::Classes`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Classes.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

