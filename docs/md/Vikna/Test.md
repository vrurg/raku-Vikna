NAME
====



`Vikna::Test` - [`Test::Async`](https://modules.raku.org/dist/Test::Async) bundle for testing Vikna framework

DESCRIPTION
===========



This bundle utilizies asynchronous capabilities of [`Test::Async`](https://modules.raku.org/dist/Test::Async) for cope with threaded nature of Vikna.

### Event Sequencer Syncronizers

In certain situations, especially when testing interaction of a few widgets, it is necessary to synchronize two or more asynchronous test suites. For example, *t/widget/01-basic.t* tests for a widget changing its position. To make sure that not only widget geometry has changed but that these changes were then reflected on the screen one needs to know that the widget has done its first redraw after moving and submitted its canvas to the desktop. Only then another test can start monitoring desktop events to catch up with `Event::Screen::Ready` known that it is a consequence of the widget position change.

Support for this is provided by *synceronizers*, or simply *syncers*. A syncer is an object returned by `ev-syncer()` routine with a given name:

    ev-syncer('Foo!').promise.then: { say "Foo! syncer fulfilled" };
    ev-syncer('Foo!').status; # Handled by the $.promise attribute

A syncer object is immutable and once requested is kept until the current process exits.

Most common scenario of using a syncer is one thread is setting its status and others react to it:

    ev-syncer('Bar').hand-over(pi);
    ...
    say await ev-syncer('Bar').promise; # 3.1415926...
    ...
    if ev-syncer('Bar').ready {
        say "Bar is ready";
        self.next-stage;
    }
    elsif ev-syncer('Bar').failed {
        say "Bar didn't pass, can't proceed";
        self.last-stage;
    }
    else {
        # Still need to await for Bar
    }

Syncer object attributes:

  * `$.name` - syncer name, as requested

  * `$.promise` - syncer promise which kept for success and broken for failure.

Syncer object methods:

  * `hand-over(Mu $value = True)` – signal success and hand over the initiative to awaiting workers

  * `abort(Mu $value = False)` - signal failure to awaiting workers

  * `signal(Bool:D $passed, Mu :$value = $passed)` – depending on `$passed` invokes either $<hand-over> or `abort` with `$value`

  * `ready()` - returns *True* is syncer is signalling success

  * `failed()` - returns *True* is syncer is signalling failure

  * `status()` – handled by `$.promise` attribute

TEST TOOLS
==========

### `is-event-sequence(Vikna::Widget:D $widget, Iterable:D $task-list, Str:D $message, :$timeout, :$async=False, :$trace-events=False, :%defaults)`

This test tool is checking if the events we're receiving on `$widget` are matching a pattern defined by `$task-list`. It is based on the idea that a widget (basically, a [`Vikna::EventHandler`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventHandler.md)) is a state machine. And thus sequencer is an observer which monitors widget state changes by pulling in and executing a task.

To implement sequencing over a `$widget` the tool is mixing in a `EvReporter` role into it (the role is internal implementation details and must not be relied upon).

Each task pulled in from `$task-list` is expected to be a hash or a list of [`Pairs`](https://docs.raku.org/type/Pairs) with the following keys:

  * `type` -- defines an event type we're expecting for

  * `skip-until` -- skip all events until a *syncer* is passed (see more on syncers below>

  * `timeout` -- for how long the event should be awaited for

  * `accept` -- a [`Code`](https://docs.raku.org/type/Code) object which returns *True* if the event is to be accepted for processing

  * `on-match` -- a [`Code`](https://docs.raku.org/type/Code) object, a callback to be invoked if the event is accepted

  * `checker` -- a [`Code`](https://docs.raku.org/type/Code) object which returns *True* if event passes the check

  * `origin` -- the object we expected in the `$.origin` attribute of the event object

  * `dispatcher` -- the object we expected in the `$.dispatcher` attribute of the event object; by default it is `$widget`

  * `on-status` -- a [`Code`](https://docs.raku.org/type/Code) object, a callback to be invoked when the status of the task is already known

  * `message` -- a message for the task `subtest`.

  * `comment` -- a comment to be attached to the task test in TAP output.

The keys are then used to initialize a new task object. There is a helper routine `evs-task` which serves as a shortcut for creating a task hash and for better readability of otherwise rather convoluted definitions of task lists:

    evs-task(Event::Redrawn, "widget redrawn itself", :timeout(10))

The task object is passed as the last parameter to any [`Code`](https://docs.raku.org/type/Code) object if defined:

    evs-task(
        Event::Redrawn, "redrawn",
        :accept(
            -> $ev, $task { ... }
        )
    )

Though the task object class is internal implementation detail and its interfaces are not published, the following rules are guaranteed to be followed:

  * All attributes named after the task keys are publicly available

  * Method `passed` is available and returns success status of the task

A sequencing task is ran right after an event has been processed by the `$widget` allowing to control the consequences of it. Then the following steps are done:

  * First of all, the task checks if there `skip-until` defined and if the *syncer* associated with is already signalled. A failed *syncer* results in task failure.

  * Event object is matched against `type` key. The match/no match is determined using smartmatch making it possible to use any kind of object as `type` value. For example, `:type(any(Event::Kbd, Event::Mouse))` would make any input from classic input devices to be accepted for further consideration.

  * If event type is ok then `accept` callback has a chance of confirming that the event is really acceptable for further processing. `:accept( -> $ev, $ { K_Shift ∈ $ev.modifiers } )` line in a task profile means that the input event must be matched only if a *Shift* key is pressed. If not the event is ignored and the sequencer will await for the next one.

  * At this point task matcher launches a hidden subtest and invokes `on-match` callback with `($ev, $task)` arguments. If `on-match` code invokes a test tool its outcome will belong to the task subtest. Also, task completion status will be the subtest success status.

  * Event `$.origin` attribute is matched against `origin` task key.

  * Event `$.dispatcher` attribute is matched against `dispatcher` task key.

  * `checker` callback is invoked with `($ev, $task)` arguments and its return value is used as task success status.

Whenever task status gets fulfilled with either success or failure, `on-status` callback is invoked with `($passed, $task)` arguments. If the task fails then the whole test application is shutdown using desktop `quit` method.

With `:async` sequencing is started in a dedicated thread. This allows to group two or more tests in a common suite and let them interact with each other using *syncers*. For example, *t/widget/010-basic.t* invokes two group of tests: one to control the startup sequence, the other one is to control widget geometry change. Both are started at the same time. But the second one ignores all incoming events until the first one signals success with *'move widget'* *syncer*. Yet, within both multiple syncers are started because what we actually test is interaction of a widget with the desktop. Geom change test event uses two sequencers for the same widget to test different aspects of the same action.

The rest of the test tool parameters are:

  * `:timeout(Int)` defines the sequencer timeout. Exceeding it considered a failure.

  * `:trace-events` turns on dumping of events reveiced by sequencer.

  * `:%defaults` define keys common for all task profiles of this sequencer.

### `is-rect-filled(Vikna::Canvas:D $canvas, Vikna::Rect:D $rect, Str:D $message, Vikna::WAttr:D :$attr, *%c)`

Tests if a rectangle on `$canvas` is filled with a character, color, and style. The values to test for are defined as named arguments of the test tool. Those not defined are taken from `$attr` if passed in.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Canvas`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md), [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md), [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Widget.md), [`Vikna::Events`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Events.md), [`Vikna::WAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md), [`Vikna::Test::App`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Test/App.md), [`Vikna::Test::OS`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Test/OS.md), [`Vikna::Test::Screen`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Test/Screen.md), [`Test::Async`](https://modules.raku.org/dist/Test::Async)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

