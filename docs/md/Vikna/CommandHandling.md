NAME
====



`Vikna::CommandHandling` - role implementing command emission and processing.

DESCRIPTION
===========



This role unifies processing of `Event::Command` category of events. A command is the way external code communicate to a event handling object and this is how *kick and go* principle is implemented "in flesh".

A command is an event which class is inheriting from `Event::Command`. It has two distinctive properties: *completion status* and *arguments*.

*Arguments* is just a capture to invoke a command handler with. *Completion status* is a [`Promise`](https://docs.raku.org/type/Promise) which is kept with command handler return value.

Command Handlers
----------------

A command handler is a method which would be invoked by event loop flow to react on a command event. For example:

    $widget.move: $x, $y;

results in:

  * `Event::Cmd::SetGeom` is dispatched with a capture of `\($x, $y)` form

  * it passes all the usual stages of event dispatching

  * event loop invokes `cmd-setgeom` method, so that it receives two positionals from the capture above

  * `Event::Cmd::SetGeom` object is completed with `cmd-setgeom` result

The method name of an event handler can be defined by the command event class using `cmd` method which should return the name. Otherwise method name is formed from the class name by stripping off the `Event::` namespace prefix. The rest of the event class name parts are lowercased and joined with `-`. This is how in the example above we get `cmd-setgeom` from `Event::Cmd::SetGeom`. Another example of the transformation is `Event::Cmd::Scroll::To` becomes `cmd-scroll-to`.

If command handler of the given name doesn't exists then `CMD-FALLBACK` is tried. If found it is invoked with the only parameter – the command event itself.

No handler for a command event it not an error situation. Such event would be silently ignored.

METHODS
=======



`multi event(Event::Command:D $ev)`
-----------------------------------

Responsible for implementing the command handling.

`multi send-event(Event::Command:U \evType, |args)`
---------------------------------------------------

`multi send-event(Event::Command:U \evType, Capture:D $args)`
-------------------------------------------------------------

`multi send-event(Event::Command:U \evType, Capture:D $args, %params)`
----------------------------------------------------------------------

The method is a [`Vikna::Event::Handling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Event/Handling.md) `send-event` convenience wrapper. Similarly to `dispatcher` method, `send-command` creates an event object and passes it for event loop handling. The difference is that because a command must always be submitted to the object it is originated by, `send-command` bypasses `route-event` and submits directly into `send-event` method.

`args` and `$args` captures are passed down to the command handle method.

`%params` is used as event constructor profile.

Returns `send-event` return value.

SEE ALSO
========

[Vikna](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [Vikna::Manual](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [Vikna::CommandHandling](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CommandHandling.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

