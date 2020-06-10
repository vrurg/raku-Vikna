PREFACE
=======



Sorry, but I didn't solve the problem of the first word. So, let me use this paragraph as a cheat, not as a solution.

CONCEPTS
========



This section is briefly describing the basic building blocks of the framework and the ideas moartaring them together.

[Vikna::Object](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Object.md)
----------------------------------------------------------------------------------------

This is the root parent class of almost any other Vikna class except for a few basic data types. It implements the followin key functions:

  * object identification (id and name)

  * object-aware exception throwing

  * object creation with custom profile support

  * code flow

As usual, more details are provided in the class documentation. Code flow will be explaned later in this document. But right now I would focus a bit on ...

... Custom Profiles
-------------------

A *profile* is a set of named parameters passed over to a class constructor to create a new class instance. For example:

    my %profile = name => 'myName', foo => 42;
    my $foo = Foo.new: |%profile;

The example demoes the most simple case we can imagine. In real life when one creates a new object it's profile values can come from:

  * hard-coded arguments of `new` method

  * an external configuration

  * defaults of the class itself or its parents

Vikna provide a unified way to merge all sources into a final profile to be used. This is done by allowing any type object to have its own `submethod` `profile-default` which is expected to return a profile object coercable into a [`Hash`](https://docs.raku.org/type/Hash) which would contain what the type object conisders to be viable defaults. [Vikna::Object](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Object.md) then iterates over the `submethods` in reverse RMRO order (the same as for the construction time submethods, see [RMRO](#RMRO) below), collects the profiles, and merges them into a final default one.

When the default profile is built, [Vikna::Object](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Object.md) then runs it alongside with profiles obtained from the constructor method arguments and from a config file (not implemented yet) through another `submethod` `profile-checkin`. The job of `profile-checkin` is to adjust the final profile so as to adjust some values according to demands of its owning type object. For example, `Vikna::Object::profile-checkin`, which would be invoked first, simply merges default, config, and constructor profiles in the order mentioned into the destination hash. Any subsequent `profile-checkin` would need to modify that final profile if necessary.

An example of how it works can be found in [Vikna::Widget](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Widget.md) class. It allows creating a new widget by either specifying widget's geometry explicitly, via an instance of [Vikna::Rect](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md), or by passing `x`, `y`, `w`, `h` keys. In the latter case [Vikna::Widget](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Widget.md) implicitly create a new `geom` key and removes redundant coordinate keys from the profile. Similarly it handles widget attribute parameters.

One of the future concepts I plan to be implemented with custom profiles is *themes* support. A theme could have own configuration file which would be read by the application and passed into the custom profile processing.

### RMRO

Despite the greatest efforts of Raku/Rakudo documentation team, they can't keep up with the pace of core development. For this reason I'd try to briefly explain the RMRO principle here because there no documentation for it yet. Additional information can be found in [my blog post](http://blogs.perl.org/users/vadim_belman/2019/12/post.html).

Actually, everything is rather simple here. [MRO](https://docs.raku.org/language/objects#Inheritance) is well documented and basically it is an order in which parent classes of a given class are considered when, say, a method is resolved. RMRO is almost the same thing but in addition to classes it also includes consumed roles.

Lazy Attributes
---------------

Vikna use lazy attribute implementation by [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish:cpan:VRURG).

Code Flows
----------

One of the problems with debugging a heavily threaded application without a debugger is tracing down messages belonging to a particular thread. A situation could be worsened by the fact that sometimes two or more threads could be logically linked to each other. And in few cases I said myself: even though this method doesn't fork into a thread, it still worth considering it separately from the surrounding code!

So, the *code flows* were born. They turned out to be especially useful with code tracing sub-framework provided by [Vikna::Tracer](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Tracer.md) and revealed via `Vikna::Object::trace` method. But they proved to be useful in exception reporting too.

Canvas And Invalidating
-----------------------

Canvas is something we draw on. And the drawing is mostly implemented via *imprinting*. Sorry, a quirk of a text-based UI!

A canvas in its normal state is actually immutable. It means, no imprinting would change its state. Drawing is only allowed on invalidated rectangles. This way two goals are achieved. First, it might simplify drawing logic in many cases so that a client using canvas doesn't need to test for boundaries to only update a part of its canvas. Second, it works as an optimization cutting off unnecessary operations.

Canvas is a rectangle of cells. Each cell is represented by four of its attributes: a *character*, a *foreground* and a *background* colors, and *style* (like **bold** or *italic*, etc.). One or many cells on a canvas can be partially or fully transparent. No, it doesn't mean alpha blending or anything like this! It only means that any of cell attributes can be transparent on its own. So, when one canvas is imprinted onto another and one of its cells has transparent background (just unspecified, for that matter), and the target cell has it set to *blue*, then the result of imprinting will have *blue* background.

The [README](https://github.com/vrurg/raku-Vikna) contains a GIFed demo where this behavior is nicely demonstrated when the moving window floats under the static one.

Widget
------

Do I need to explain this one? Ok, dear visitor, it's time to move on to another exhibit...

Events And Event Handling
-------------------------

An event is a class instance inheriting from [Vikna::Event](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Event.md). Events are split into categories. But what's more important, events in Vikna also have priorities. But I'll get back to it a little later.

Handling of events always happens in a dedicated thread. Literally, almost every object capable of event handling has an associated thread which runs its event loop. While it might sound like "wow, isn't it gonna be too many threads?", I'd say: yes, most like it is. But considering the nature of a UI application, most of the time these threads would be spending awaiting. Memory consuming – yes, but otherwise no harm is expected. For example, Rakudo re-uses OS-level threads so that one system thread could be shared among many application threads unless they all is ran simultaneously.

The advantage we get with this model is as fast widget response to an event as possible.

Let me step aside here and tell you a bit of Vikna history. At some point I needed to develop a web scraper to assist my wife in her work. In the process I wished I could output reports from different scraper threads into individual windows. So, the scraper turned out to be unneeded after all, but the initial idea is currently implemented by Vikna. Say, an instance of [Vikna::TextScroll](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/TextScroll.md) can be used like this:

    $!reporter = self.create: Vikna::TextScroll, ...;
    ...
    $!reporter.print: "Hello";
    $!reporter.say: " World!";

Simple, heh? More importantly, the same object can be used from many threads at the same time!

This is what I call *the principle of kick and go*: you kick a widget and while it does its job, you do yours.

Another problem we get solved with single-threaded event loop is avoidance of a *lock mayhem*. What I mean here is a situation where race conditions are avoided with locks protecting internal object state. Or with a single lock protecting the whole object itself (see [`OO::Monitors`](https://modules.raku.org/dist/OO::Monitors:cpan:JNTHN). The first case is risking ending up with many cases of deadlock. The second could suffer from performance loss in some cases.

As a bottom line we can say that the model chosen for Vikna allows combining the advantages of a state machine architecture for maintaining object state while providing all the advantages of fully async interfaces for code using it.

*Note* that to model be the most effective any reaction to an event must be as short in time as possible. So far, the longest operation happening within an event loop thread is actual widget drawing. Yet a measure was taken to minimize its impact on the overall performance.

Event Origin And Dispatcher
---------------------------

Every event has two key properties attached: *origin* and *dispatcher* objects. The *origin* is purely informative but very important property as it allows in certain cases to make a decision on whether we must or must not react to an event. For example, command events handling code throws if a command received has been originated by another another object.

*dispatcher* has more influence over the event lifecycle as it is explicitly tells the even loop code which object is to handle the event. Commonly, both *origin* and *dispatcher* point to the same originating object. But, for example, events coming event sources (see [Vikna::EventHandling](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/EventHandling.md)) would typically have their *origin* set to the source while dispatcher will point to the widget the source is attached to.

Event Priority
--------------

The *kick and go* principle mentioned above have a downside. Imagine a situation where your widget moves and changes a lot but have to react to user keypresses as fast as possible? Your code basically would look this way:

    until $done {
        $!widget.set-geom: self.calculate-new-geom;
    }

Apparently, this would involve both moving and redrawing. Our loop would flood the widget with geometry change events it wouldn't be able to handle timely. And even though redraw events are postponed and dropped if another redraw is requested, it would still cause any other event thrown into the queue to wait for its turn too long than it is considered acceptable for a user interaction handling. Not to be mentioned that geometry change events on their own could cause the postponed redraw events to come too late!

The solution is to give every event a priority. This way we could ensure that a key pressed by a user will be taken care of as soon as the current event is processed. And that a postponed redraw event would push back any geometry change one and we wouldn't observe a widget jumping from it's initial position to the final one with no intermediates.

*BTW, implementation of this concept has resulted in [`Concurrent::PChannel|https://modules.raku.org/dist/Concurrent::PChannel:cpan:VRURG`](`Concurrent::PChannel|https://modules.raku.org/dist/Concurrent::PChannel:cpan:VRURG`) development which is now in the core of Vikna's event loop.*

Each event category has a default priority value assigned, but each individual event could get it's own one too.

Event Sources
-------------

What are the typical sources for events? Keyboard, mouse, internal program state changes. Ok, but what if I have, say, a remote device of any kind producing them for me? One solution would be to simply have something like:

    $device.Supply.tap: -> $ev { self.dispatch: $ev };

but sometimes things are a bit more complicated than that. To provide a way for incapsulation of the code taking care of such case, event handling subsystem supports so called *event sources*. A *source* is an object which produces Vikna-capable events. Examples of such objects are [Vikna::Screen::ANSI](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Screen/ANSI.md) and `Input` defined in [Vikna::OS::unix](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/OS/unix.md).

An event source can be attached to any event handling object. For example, imagine one having a bunch of sensor reporting their status back to our application. We can have a window per sensor with an event source translating sensor data into specific events and injecting them into window's event loop. In this case the rest of the system won't care about those events, the window doesn't need to filter out the events belonging to it. And to stop monitoring of a sensor it'd be enough to just close its associated window! Besides, the driver for the sensor can be supplied by a third party, so we would just `use` a module:

    use MyApp::Sensor;

    class SensorWin is Vikna::Window {
        multi method event(Event::Init:D) {
            self.add-event-source: MyApp::Sensor, :$!device-IP;
        }
        multi method event(Event::Sensor::Overload:D $ev) {
            self.alert-report: $ev.cause;
        }
    }

Event Tagging
-------------

An event could have tags attached to it. A tag is an object which would help us identify the event in the stream of all events handled by an object. For example, if an event is tagged with a string *"foo"* then we can take a special action against it somewhere in a handler:

    multi method event(Event::Foo:D $ev) {
        if "foo" ∈ $ev.tags {
            # Gotcha!
            self.take-the-foo-action;
        }
    }

Tags are event more useful that that because they're *viral*. If a new event dispatched in a dynamic context with `$*VIKNA-CURRENT-EVENT` then it is considered to be the event-initiator and the new event will inherit it's tags from the initiator unless they were manually set.

Another way to tag events is to use routine `tag-event` from [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Utils.md). If both event-initiator has tags and a `tag-event` is in effect then the new event instance will have all tags merged into one set.

Tag inheritance allows tracking series of events logically linked together. See for example [`Vikna::Widget::Group`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Widget/Group.md) and how it implements synchronous group flattening.

Parent/Child Strata
-------------------

Nothing has been said so far about parent/child relations of widgets because this is something intrinsic to probaly every UI architecture out there. But what has to be mentioned is that in Vikna children are grouped into strata. There are three of them whith self-explaining names: `StBack`, `StMain`, and `StModal`. Apparently, the purpose is to simplify management of children Z-order. Simply put, if a child widget is installed into `StBack` then whenever it requests to be moved atop, it won't overlap any window from `STMain`.

You can see how widget `EventList` from [the window example script](https://github.com/vrurg/raku-Vikna/blob/master/examples/window.raku) is using `StBack` stratum to stay below both windows.

As long as any widget can be both parent and child, strata are per-widget thing. It makes per-widget modality possible.

Application
-----------

An application is a glue which binds together OS-dependant layer (*drivers* of a kind) and desktop widget.

PRINCIPLES
==========



The framework is built upon a few principles enlisted in this chapter.

Kick And Go Use Pattern
-----------------------

While user code does its work, Vikna do the work for the user code. I.e. the best implementation of anything is when users can focus on solving their problems and only send as simple as possible commands to Vikna or receive simple and clear responses. One of the best example of the implemenation of this principle is [`Vikna::TextScroll`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/TextScroll.md) widget which can be used as a kind of simple terminal object with `say` and `print` methods:

    $ts.say: "Put something\rSay\non the widget";

That's it. We *kick* a `Vikna::TextScroll` object in `$ts` with `say` command and we *go* on with own business. Vikna will do the rest transparently.

Responsive Event Handling
-------------------------

No event should be processed longer than it takes to irritate the end user. If an event results in an unavoidably long code run then the code must be forked into a separate async flow.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md), [`Vikna::Classes`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Classes.md), [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Widget.md)

AUTHOR
======



Vadim Belman <github:vrurg>

