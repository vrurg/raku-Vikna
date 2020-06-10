use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::EventHandling> – role implementing event loop and dispatching

=DESCRIPTION

This role implicitly starts a new event-handling thread for the object which consumes it.

The process of event dispatching is split into two stages, depending on which code flow is handling event packet. The
first stage is done within the code flow which sends an event. It includes:

=item method C<dispatch>
=item event routing with C<route-event> method
=item optional filtering
=item sending the packet over event channel

The second stage is the event loop itself where received event packet:

=item received and handled
=item passed into to method C<event>
=item submitted to subsribers (see C<subscribe> method below)

See also event-related sections in L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>.

=ATTRIBUTES

=head2 C<Supply:D $.events>

Subscription supply where processed event packets are submitted to.

=METHODS

=head2 C<multi dispatch(Event:U \evType, EventPriority $priority?, *%params)>

The method to dispatch events:

    self.dispatch: Event::Idle;

C<%params> will be passed over to event constructor as profile:

    self.dispatch: Event::MyEvent, :foo(42);

is equivalent to:

    self.dispatch: Event::MyEvent.new(:origin(self), :dispatcher(self), :foo(42));

If C<$priority> is specified it is also added to the event constructor profile so that the resulting event object
will have it's C<profile> attribute as specified by the caller.

The newly created event instance is fed back to C<dispatch> method for final dispatching.

=head2 C<multi dispatch(Event:D $ev, EventPriority $priority?)>

This C<dispatch> candidate submits event packet to C<route-event> method. But prior it checks if we're recorded as
the event dispatcher. If not, the event is cloned with C<:dispatcher(self)> parameter and the clone is then sent down to
C<route-event>. If C<$priority> is defined it doesn't affect the value of C<$ev> C<priority> attribute and only used
as explicit instruction for C<send-event> method.

Returns C<route-event> return value.

=head2 C<re-dispatch(Event:D $ev, |c)>

Similar to the second C<dispatch> candidate but doesn't alter the event object whatsoever. Capture C<c> is bypassed to
C<route-event> method.

=head2 C<start-event-handling()>

This method is implicitly invoked at construction time. Starts the event loop code flow.

=head2 C<stop-event-handling()>

Shuts down all event sources, unsubscribes the object from all of its subscriptions, and closes the even queue.

Returns a promise which is kept when all queued events are processed.

=head2 C<multi handle-event(Event:D $ev)>

Stage 2 method. It does three things:

=item installs an event monitor (see below)
=item passes the event packet C<$ev> to C<event> method
=item forks code flow and emits C<$ev> to subscribers

The event monitor is responsible for not letting an event to be processed for longer than a certain interval. Current
interval is hardcoded at 15 seconds. The reason for the monitor to exists is to:

=item prevent user code from accidental deadlocks
=item prevent user code from doing too extensive operations within the event loop. This imposes the principle of code
responsiveness to event processing code (see I<PRINCIPLES> chapter in
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>).

=head2 C<send-event(Event:D $ev, EvenPriority :$priority?)>

Stage 1 method. The first thing it does it tries to invoke C<event-filter> method on self. If succeeds then event(s)
returned by the method are used as replacement for C<$ev> argument. Then event(s) are send over the event queue into
the event loop flow if the queue is defined. Otherwise the event is passed directly into C<$ev.dispatcher>
C<handle-event> method. This last variant is used by widget groups (see
L<C<Vikna::Widget::Group>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Widget/Group.md> and
L<C<Vikna::Widget::GroupMember>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Widget/GroupMember.md>).

Throws C<X::Event::Stopped> if event loop has been stopped already.

Returns event(s) that were actually pushed into the event queue.

=head2 C<multi route-event(Event:D $ev, *%c)>

Stage 1 method. By default re-transmits C<$ev> to C<send-event>. But it allows some early re-routing of events before
they're pushed into the queue. For example,
L<C<Vikna::Focusable>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Focusable.md>
is using this method to re-dispatch focus-dependent events directly to the widget in focus.

=head2 C<multi drop-event(Event:D $ev)>

This method is invoked instead of C<handle-event> when event loop is shut down but an event comes from the queue.
Normally does nothing except for C<Event::Command> category of events which are I<completed> with
C<X::Event::Dropped> exception with C<False> mixin.

=head2 C<multi event(Event:D $ev)>

Prototype for consuming class C<event> method candidates.

=head2 C<multi event-filter(Event:D $ev)>

Prototype for event filtering method invoked by C<send-event>. By default returns just C<[$ev]>.

=head2 C<multi add-event-source(Vikna::EventEmitter:U \evsType, |c)>

Instantiates C<evsType> passing capture C<c> to the constructor. Then re-submits the instance to the next candidate.

=head2 C<multi add-event-source(Vikna::EventEmitter:D $evs)>

Adds C<$evs> to the list of event handling object event sources. Installs a tap on C<$evs>
L<C<Supply>|https://docs.raku.org/type/Supply> which redispatches emitted event objects.

=head2 C<subscribe(Vikna::EventHandling:D $obj, &code?)>

Subscribes self to another event handling object. If C<&code> argument is defined then it is invoked for each event from
the subscription with the event packet as the only parameter. Otherwise, the event is submitted to C<subscription-event>.

=head2 C<unsubscribe(Vikna::EventHandling:D $obj)>

Cancels the subscription to C<$obj>. Throws C<X::Event::Unsubscribe> if no such subscription has been made earlier.

=head2 C<queue-protect( &code )>

Lock-protects invocation of C<&code> to prevent race conditions with event loop flow. It allows to pause the event queue
processing while we do something in a parallel thread:

    $child.queue-protect: {
        # Neither $my-event nor any other event won't be processed by $child event loop until foo finishes and this code
        # block returns.
        $child.dispatch: $my-event;
        self.foo;
    }

=head3 C<is-event-queue-flow()>

Returns I<True> if the invoking context belongs to an event handling flow of C<self>.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>,
L<C<Vikna::Events>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Events.md>,
L<C<Vikna::CommandHandling>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/CommandHandling.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

unit role Vikna::EventHandling;

use Vikna::Events;
use Vikna::Utils;
use Vikna::EventEmitter;
use Vikna::X;

use Concurrent::PChannel;
use AttrX::Mooish;

has Int $.stuck-timeout = 180;

has Supplier:D $.events .= new;

has Lock::Async:D $!ev-lock .= new;
has Lock::Async:D $!send-lock .= new;

has Concurrent::PChannel $!ev-queue;
has %!subscriptions;

has @!event-source;

has Bool:D $!event-shutdown = False;

submethod TWEAK {
    self.start-event-handling;
}

method !run-ev-loop {
    self.trace: "Starting event handling", :event;
    my $*VIKNA-EVQ-OWNER = self;
    loop {
        CATCH {
            note "===EVENT KABOOM=== on { self.?name // self.WHICH }! ", .message, ~.backtrace;
            default {
                self.trace: "EVENT HANDLING THROWN:\n", .message, .backtrace, :error;
                unless self.?on-event-queue-fail($_) {
                    $!ev-queue.fail($_) if $!ev-queue;
                    # self.stop-event-handling;
                    self.trace: "RETHROWING ", $_.WHICH;
                    self.panic($_)
                }
            }
        }
        my $*VIKNA-CURRENT-EVENT =
            my $ev = $!ev-queue.receive;
        if $ev ~~ Failure {
            if $ev.exception ~~ X::PChannel::OpOnClosed {
                $ev.so;
                last;
            }
            $ev.exception.rethrow;
        }
        $!ev-lock.protect: {
            if $!event-shutdown {
                self.trace: "EVENT QUEUE SHUTDOWN, dropping event ", $ev;
                # XXX Shouldn't it be $ev.dispatcher.?drop-event?
                self.?drop-event($ev);
            }
            else {
                self.handle-event($ev);
            }
        }
    }
    $!events.done;
}

method start-event-handling( ::?ROLE:D: ) {
    $!ev-lock.protect: {
        unless $!ev-queue {
            $!ev-queue = Concurrent::PChannel.new(:priorities( EventPriority.^elems ));
            self.flow: { self!run-ev-loop }, :name( 'EVENT LOOP ' ~ ( self.?name // self.WHICH ) );
        }
    }
}

method stop-event-handling( ::?ROLE:D: ) {
    LEAVE {
        $!event-shutdown = True;
        .close with $!ev-queue;
    }
    # Ignore closed channel on shutdown as it might be caused by a panic exit and we don't want to add to the bail-out
    # noise.
    CATCH {
        when X::PChannel::OpOnClosed {}
        default {
            .rethrow
        }
    }

    .shutdown for @!event-source;
    # Unsubscribe from all.
    .close for %!subscriptions.values;
    .send: ( my $nop = self.create: Event::Cmd::Nop, :dispatcher( self ) ), PrioIdle with $!ev-queue;
    $nop ?? $nop.completed !! Promise.kept(True)
}

proto method handle-event( ::?ROLE:D: Event:D $ev ) {*}
multi method handle-event( ::?ROLE:D: Event:D $ev ) {
    self.trace: "HANDLING[thread:{ $*THREAD.id }] ", $ev, :event;
    my $ev-handled = Promise.new;
    my $vf = $*VIKNA-FLOW;
    my $p = Promise.in($!stuck-timeout).then({
        my $*VIKNA-FLOW = $vf;
        if $ev-handled.status ~~ Planned {
            self.trace: "STUCK EVENT ", $ev;
            note $.name, " STUCK EVENT ", $ev;
        }
        CATCH {
            default {
                note "EVENT MONITOR THROWN: ", $_;
            }
        }
    });

    self.event($ev);

    $ev-handled.keep(True);

    self.trace: "EMITTING EVENT for subscribers: ", $ev, :event;
    self.flow: { $!events.emit: $ev }, :name( 'EVENT SUBSCRIBERS ' ~ self.name );
    self.trace: "DONE HANDLING ", $ev, :event;
}

method subscribe( ::?ROLE:D $obj, &code? ) {
    %!subscriptions{$obj.id} = $obj.events.Supply.tap: &code // { self.subscription-event: $_ };
}

method unsubscribe( ::?ROLE:D $obj ) {
    my $id = $obj.id;
    with %!subscriptions{$id}:delete {
        .close;
    }
    else {
        self.throw: X::Event::Unsubscribe, :subscription-obj( $obj )
    }
}

method send-event( Vikna::Event:D $ev, EventPriority :$priority? ) {
    # note "SEND-EVENT: ", $ev;
    self.trace: "SEND-EVENT: ", $ev, :event;
    self.throw: X::Event::Stopped, :$ev if $!event-shutdown;
    my Vikna::Event:D @events = $ev;
    $!send-lock.protect: {
        @events = $_ with $ev.dispatcher.?event-filter($ev);
    }
    for @events -> $filtered {
        # If event queue is not initialized then work synchronously.
        if $!ev-queue {
            self.trace: "QUEUEING(prio:{ ( $priority // $filtered.priority ).Int }) ", $filtered, :event;
            CATCH {
                when X::PChannel::OpOnClosed {
                    self.throw: X::Event::Stopped, ev => $filtered;
                }
                default { .rethrow }
            }
            $!ev-queue.send: $filtered, ( $priority // $filtered.priority ).Int;
        }
        else {
            self.trace: "DIRECT HANDLING ", $filtered, :event;
            $ev.dispatcher.handle-event: $filtered;
        }
    }
    @events
}

proto method route-event( ::?ROLE:D: Event:D, | ) {*}
multi method route-event( ::?ROLE:D: Event:D $ev, *%c ) {
    self.trace: "Routing event via send ", $ev, :event;
    self.send-event: $ev, |%c
}

proto method dispatch( ::?ROLE:D: Event, | ) {*}
multi method dispatch( ::?ROLE:D: Event:D $ev, EventPriority $priority? ) {
    self.trace: "Dispatching definite event packet ", $ev;
    self.route-event:
        ( self === $ev.dispatcher ?? $ev !! $ev.clone(:dispatcher( self )) ),
        |( $priority ?? :$priority !! (  ) )
}
multi method dispatch( ::?ROLE:D: Vikna::Event:U \EvType, EventPriority $priority?, *%params ) {
    self.trace: "Dispatching event type ", EvType.^name;
    my %defaults = :origin( self ), :dispatcher( self );
    %defaults.append: :$priority if $priority.defined;
    my $ev = self.create: EvType, |%defaults, |%params;
    self.trace: "NEW EVENT ", $ev, " with params:\n", %params.pairs».map({ "  " ~ .key ~ " => " ~ ( .value // '*undef*' ) }).join("\n");
    self.dispatch: $ev;
}

# Preserve event's dispatcher.
method re-dispatch( ::?ROLE:D: Event:D $ev, |c ) {
    self.route-event: $ev, |c
}

# This method must be used ONLY when we know for sure that event isn't going to be passed to event() method.
proto method drop-event( ::?CLASS:D: Event:D )  {*}
multi method drop-event( Event::Command:D $ev ) {
    self.trace: "DROPPING ", $ev;
    $ev.complete(X::Event::Dropped.new(:obj( self ), :$ev) but False)
        if $ev.completed.status ~~ Planned;
}
multi method drop-event( Event:D ) {}

proto method event( ::?ROLE:D: Event:D $ ) {*}
# Sink event. Don't drop it because it might have been handled previously and happened to end up here as a result of
# next/callsame.
multi method event( ::?ROLE:D: Event $ ) {}

proto method event-filter( ::?ROLE:D: Event:D ) {*}
multi method event-filter( ::?ROLE:D: Event:D $ev ) {
    [$ev]
}

multi method add-event-source( Vikna::EventEmitter:U \evs-type, |c ) {
    self.add-event-source: self.create(evs-type, |c);
}

multi method add-event-source( Vikna::EventEmitter:D $evs ) {
    self.trace: "add-event-source for ", $evs.name;
    push @!event-source, $evs;
    $evs.init;
    my $evs-tap;
    $evs.Supply.tap:
        -> Event:D $ev {
            self.trace: "EVENT FROM SOURCE: ", $evs.name, ", ev object: ", $ev.WHICH, ", shutting down? ",
                $!event-shutdown, ":\n    ", $ev;
            self.dispatch: $ev unless $!event-shutdown;
        },
        tap => -> $tap { $evs-tap = $tap },
        done => { $evs-tap.close },
        quit => { $evs-tap.close };
}

# Pause event processing to allow 3rd party safely operate with the widget.
method queue-protect( &code ) {
    $!ev-lock.protect: {
        &code( )
    }
}

method is-event-queue-flow {
    with $*VIKNA-EVQ-OWNER {
        return $*VIKNA-EVQ-OWNER === self
    }
    False
}

submethod DESTROY {
    .close with $!ev-queue;
}
