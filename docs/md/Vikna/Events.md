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

There is a situation possible where an event is considered to be not on time and gets postponed for later. An example of such situation is described in *Redraw Hold* section of [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Widget.md). In this situation it might be considered useful to dispatched the event with slightly higher priority to handle it as soon as possible. This is what `PrioReleased` is useful for. In the case of *redraw holding* it allows the redraw command to be processed before any other command queued making it very likely for the redraw to happen almost right away after the previos one is finished.

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

Events consuming this role are routed using the rules of focused dispatching, as implemented by [`Vikna::Focusable`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Focusable.md).

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

Does `Event::Geomish`. Subcategory of geomish events containing information about a transformation of some kind where state is changing *from* one rectangle *to* another. Adds `$.from` attribute of [`Vikna::Rect:D`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md).

Role `Event::Positionish`
=========================

Subcategory of events bearing information about some 2D position. Defines attribute `$.at` of [`Vikna::Point:D`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Point.md) and handling methods ro-accessors `x` and `y`.

Role `Event::Vectorish`
=======================

Subcategory of events defining a vector-like information with *from* and *to* positions. Correspondingly, defines attributes `$.from` and `$.to` of [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Point.md).

Role `Event::Pointer::Elevatish`
================================

Subcategory of events which might move a widget to the top of Z-order.

Role `Event::Childing`
======================

Subcategory of events bearing information about a [`Vikna::Child`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Child.md). Defines attribute `$.child`.

Role `Event::Parentish`
=======================

Subcategory of events bearing information about a [`Vikna::Parent`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Parent.md). Defines attribute `$.parent`.

Role `Event::Relational`
========================

Does `Event::Childish` and `Event::Parentish`. Events with information about both parent and child objects.

`Event::Informative`
====================

Is `Event`, does `Event::Prio::Default`. Events of this class are only informing about something.

`Event::Command`
================

Is `Event`, does `Event::Prio::Command`.

Pass a command to an event handler. Support provided by [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CommandHandling.md).

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

There is a shortcut method `send-command` defined in [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CommandHandling.md).

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

Modifier keys. See `ModifierKeys` enum in [`Vikna::Dev::Kbd`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Dev/Kbd.md).

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

### [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Point.md) `$.prev`

Previous mouse position. The first ever mouse event will have it undefined.

Methods
-------

### `dup(*%p)`

Duplicates the event object.

### `kind()`

Returns string *'mouse'*.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md), [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Point.md), [`Vikna::Child`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Child.md), [`Vikna::Parent`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Parent.md), [`Vikna::Dev::Kbd`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Dev/Kbd.md), [`Vikna::CAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CAttr.md), [`Vikna::X`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/X.md), [`Vikna::Classes`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Classes.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

