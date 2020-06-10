NAME
====



`Vikna::EventHandling` – role implementing event loop and dispatching

DESCRIPTION
===========



This role implicitly starts a new event-handling thread for the object which consumes it.

The process of event dispatching is split into two stages, depending on which code flow is handling event packet. The first stage is done within the code flow which sends an event. It includes:

  * method `dispatch`

  * event routing with `route-event` method

  * optional filtering

  * sending the packet over event channel

The second stage is the event loop itself where received event packet:

  * received and handled

  * passed into to method `event`

  * submitted to subsribers (see `subscribe` method below)

See also event-related sections in [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md).

ATTRIBUTES
==========



`Supply:D $.events`
-------------------

Subscription supply where processed event packets are submitted to.

METHODS
=======



`multi dispatch(Event:U \evType, EventPriority $priority?, *%params)`
---------------------------------------------------------------------

The method to dispatch events:

    self.dispatch: Event::Idle;

`%params` will be passed over to event constructor as profile:

    self.dispatch: Event::MyEvent, :foo(42);

is equivalent to:

    self.dispatch: Event::MyEvent.new(:origin(self), :dispatcher(self), :foo(42));

If `$priority` is specified it is also added to the event constructor profile so that the resulting event object will have it's `profile` attribute as specified by the caller.

The newly created event instance is fed back to `dispatch` method for final dispatching.

`multi dispatch(Event:D $ev, EventPriority $priority?)`
-------------------------------------------------------

This `dispatch` candidate submits event packet to `route-event` method. But prior it checks if we're recorded as the event dispatcher. If not, the event is cloned with `:dispatcher(self)` parameter and the clone is then sent down to `route-event`. If `$priority` is defined it doesn't affect the value of `$ev` `priority` attribute and only used as explicit instruction for `send-event` method.

Returns `route-event` return value.

`re-dispatch(Event:D $ev, |c)`
------------------------------

Similar to the second `dispatch` candidate but doesn't alter the event object whatsoever. Capture `c` is bypassed to `route-event` method.

`start-event-handling()`
------------------------

This method is implicitly invoked at construction time. Starts the event loop code flow.

`stop-event-handling()`
-----------------------

Shuts down all event sources, unsubscribes the object from all of its subscriptions, and closes the even queue.

Returns a promise which is kept when all queued events are processed.

`multi handle-event(Event:D $ev)`
---------------------------------

Stage 2 method. It does three things:

  * installs an event monitor (see below)

  * passes the event packet `$ev` to `event` method

  * forks code flow and emits `$ev` to subscribers

The event monitor is responsible for not letting an event to be processed for longer than a certain interval. Current interval is hardcoded at 15 seconds. The reason for the monitor to exists is to:

  * prevent user code from accidental deadlocks

  * prevent user code from doing too extensive operations within the event loop. This imposes the principle of code responsiveness to event processing code (see *PRINCIPLES* chapter in [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md)).

`send-event(Event:D $ev, EvenPriority :$priority?)`
---------------------------------------------------

Stage 1 method. The first thing it does it tries to invoke `event-filter` method on self. If succeeds then event(s) returned by the method are used as replacement for `$ev` argument. Then event(s) are send over the event queue into the event loop flow if the queue is defined. Otherwise the event is passed directly into `$ev.dispatcher` `handle-event` method. This last variant is used by widget groups (see [`Vikna::Widget::Group`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Widget/Group.md) and [`Vikna::Widget::GroupMember`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Widget/GroupMember.md)).

Throws `X::Event::Stopped` if event loop has been stopped already.

Returns event(s) that were actually pushed into the event queue.

`multi route-event(Event:D $ev, *%c)`
-------------------------------------

Stage 1 method. By default re-transmits `$ev` to `send-event`. But it allows some early re-routing of events before they're pushed into the queue. For example, [`Vikna::Focusable`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Focusable.md) is using this method to re-dispatch focus-dependent events directly to the widget in focus.

`multi drop-event(Event:D $ev)`
-------------------------------

This method is invoked instead of `handle-event` when event loop is shut down but an event comes from the queue. Normally does nothing except for `Event::Command` category of events which are *completed* with `X::Event::Dropped` exception with `False` mixin.

`multi event(Event:D $ev)`
--------------------------

Prototype for consuming class `event` method candidates.

`multi event-filter(Event:D $ev)`
---------------------------------

Prototype for event filtering method invoked by `send-event`. By default returns just `[$ev]`.

`multi add-event-source(Vikna::EventEmitter:U \evsType, |c)`
------------------------------------------------------------

Instantiates `evsType` passing capture `c` to the constructor. Then re-submits the instance to the next candidate.

`multi add-event-source(Vikna::EventEmitter:D $evs)`
----------------------------------------------------

Adds `$evs` to the list of event handling object event sources. Installs a tap on `$evs` [`Supply`](https://docs.raku.org/type/Supply) which redispatches emitted event objects.

`subscribe(Vikna::EventHandling:D $obj, &code?)`
------------------------------------------------

Subscribes self to another event handling object. If `&code` argument is defined then it is invoked for each event from the subscription with the event packet as the only parameter. Otherwise, the event is submitted to `subscription-event`.

`unsubscribe(Vikna::EventHandling:D $obj)`
------------------------------------------

Cancels the subscription to `$obj`. Throws `X::Event::Unsubscribe` if no such subscription has been made earlier.

`queue-protect( &code )`
------------------------

Lock-protects invocation of `&code` to prevent race conditions with event loop flow. It allows to pause the event queue processing while we do something in a parallel thread:

    $child.queue-protect: {
        # Neither $my-event nor any other event won't be processed by $child event loop until foo finishes and this code
        # block returns.
        $child.dispatch: $my-event;
        self.foo;
    }

### `is-event-queue-flow()`

Returns *True* if the invoking context belongs to an event handling flow of `self`.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md), [`Vikna::Events`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Events.md), [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/CommandHandling.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

