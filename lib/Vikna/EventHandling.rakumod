use v6.e.PREVIEW;

unit role Vikna::EventHandling;

use Vikna::Events;
use Vikna::Utils;
use Vikna::EventEmitter;
use Vikna::X;

use Concurrent::PChannel;
use AttrX::Mooish;

has Supplier:D $.events .= new;

has Lock::Async:D $!ev-lock .= new;
has Lock::Async:D $!send-lock .= new;

has Concurrent::PChannel $!ev-queue;
has %!subscriptions;

has @!event-source;

has Bool:D $!event-shutdown = False;

submethod TWEAK {
    # note "TWEAK({self.WHICH}):start-event-handling";
    # note self.^mro(:roles).map( *.^name ).join(", ");
    self.start-event-handling;
    # note "TWEAK:start-event-handling done";
}

method !run-ev-loop {
    $.trace: "Starting event handling", :event;
    my $*VIKNA-EVQ-OWNER = self;
    loop {
        CATCH {
            note "===EVENT KABOOM=== on {self.?name // self.WHICH}! ", .message, ~.backtrace;
            default {
                $.trace: "EVENT HANDLING THROWN:\n", .message, .backtrace, :error;
                unless self.?on-event-queue-fail($_) {
                    $!ev-queue.fail($_) if $!ev-queue;
                    # self.stop-event-handling;
                    $.trace: "RETHROWING ", $_.WHICH;
                    $.panic($_)
                }
            }
        }
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
                $.trace: "EVENT QUEUE SHUTDOWN, dropping event ", $ev;
                self.?drop-event($ev);
            }
            else {
                $ev.dispatcher.handle-event($ev);
            }
        }
    }
    $!events.done;
}

method start-event-handling(::?ROLE:D:) {
    $!ev-lock.protect: {
        unless $!ev-queue {
            $!ev-queue = Concurrent::PChannel.new( :priorities(EventPriority.^elems) );
            $.flow: { self!run-ev-loop }, :name('EVENT LOOP ' ~ (self.?name // self.WHICH));
        }
    }
}

method stop-event-handling(::?ROLE:D:) {
    LEAVE {
        $!event-shutdown = True;
        .close with $!ev-queue;
    }
    # Ignore closed channel on shutdown as it might be caused by a panic exit and we don't want to add to the bail-out
    # noise.
    CATCH {
        when X::PChannel::OpOnClosed { }
        default {
            .rethrow
        }
    }

    .shutdown for @!event-source;
    # Unsubscribe from all.
    .close for %!subscriptions.values;
    .send: (my $nop = $.create: Event::Cmd::Nop, :dispatcher( self )), PrioIdle with $!ev-queue;
    $nop ?? $nop.completed !! Promise.kept(True)
}

proto method handle-event(::?ROLE:D: Event:D $ev) {*}
multi method handle-event(::?ROLE:D: Event:D $ev) {
    $.trace: "HANDLING[thread:{$*THREAD.id}] ", $ev, :event;
    my $ev-handled = Promise.new;
    my $vf = $*VIKNA-FLOW;
    my $p = Promise.in(15).then({
                my $*VIKNA-FLOW = $vf;
                if $ev-handled.status ~~ Planned {
                    $.trace: "STUCK EVENT ", $ev;
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

    $.trace: "EMITTING EVENT for subscribers: ", $ev, :event;
    $.flow: { $!events.emit: $ev }, :name('EVENT SUBSCRIBERS ' ~ self.name);
    $.trace: "DONE HANDLING ", $ev, :event;
}

method subscribe(::?ROLE:D $obj, &code?) {
    %!subscriptions{ $obj.id } = $obj.events.Supply.tap: &code // { self.subscription-event: $_ };
}

method unsubscribe(::?ROLE:D $obj) {
    my $id = $obj.id;
    with %!subscriptions{ $id }:delete {
        .close;
    }
    else {
        self.throw: X::Event::Unsubscribe, :subscription-obj( $obj )
    }
}

method send-event(Vikna::Event:D $ev, EventPriority :$priority?) {
    # note "SEND-EVENT: ", $ev;
    $.trace: "SEND-EVENT: ", $ev, :event;
    self.throw: X::Event::Stopped, :$ev if $!event-shutdown;
    my Vikna::Event:D @events = $ev;
    $!send-lock.protect: {
        @events = $_ with $ev.dispatcher.?event-filter($ev);
    }
    for @events -> $filtered {
        # If event queue is not initialized then work synchronously.
        if $!ev-queue {
            $.trace: "QUEUEING(prio:{($priority // $filtered.priority).Int}) ", $filtered, :event;
            CATCH {
                when X::PChannel::OpOnClosed {
                    self.throw: X::Event::Stopped, ev => $filtered;
                }
                default { .rethrow }
            }
            $!ev-queue.send: $filtered, ($priority // $filtered.priority).Int;
        }
        else {
            $.trace: "DIRECT HANDLING ", $filtered, :event;
            $ev.dispatcher.handle-event: $filtered;
        }
    }
    @events
}

proto method route-event(::?ROLE:D: Event:D, |) {*}
multi method route-event(::?ROLE:D: Event:D $ev, *%c) {
    $.trace: "Routing event via send ", $ev, :event;
    self.send-event: $ev, |%c
}

proto method dispatch(::?ROLE:D: Event, |) {*}
multi method dispatch(::?ROLE:D: Event:D $ev, EventPriority $priority?) {
    $.trace: "Dispatching definite event packet ", $ev;
    self.route-event:
        (self === $ev.dispatcher ?? $ev !! $ev.clone(:dispatcher(self))),
        |($priority ?? :$priority !! ())
}
multi method dispatch(::?ROLE:D: Vikna::Event:U \EvType, EventPriority $priority?, *%params) {
    $.trace: "Dispatching event type ", EvType.^name;
    my %defaults = :origin(self), :dispatcher(self);
    %defaults.append: :$priority if $priority.defined;
    my $ev = $.create: EvType, |%defaults, |%params;
    $.trace: "NEW EVENT ", $ev, " with params:\n", %params.pairs».map({ "  " ~ .key ~ " => " ~ (.value // '*undef*') }).join("\n");
    $.dispatch: $ev;
}

# Preserve event's dispatcher. route-event sugar, for readability.
method re-dispatch(::?ROLE:D: Event:D $ev, |c) {
    $.route-event: $ev, |c
}

# This method must be used ONLY when we know for sure that event isn't going to be passed to event() method.
proto method drop-event(::?CLASS:D: Event:D)  {*}
multi method drop-event(Event::Command:D $ev) {
    $.trace: "DROPPING ", $ev;
    $ev.complete(X::Event::Dropped.new( :obj(self), :$ev ) but False)
        if $ev.completed.status ~~ Planned;
}
multi method drop-event(Event:D)              { }

proto method event(::?ROLE:D: Event:D $) {*}
# Sink event. Don't drop it because it might have been handled previously and happend to end up here as a result of
# next/callsame.
multi method event(::?ROLE:D: Event $) { }

proto method event-filter(::?ROLE:D: Event:D) {*}
multi method event-filter(::?ROLE:D: Event:D $ev) { [$ev] }

multi method add-event-source(Vikna::EventEmitter:U \evs-type, |c) {
    $.add-event-source: $.create(evs-type, |c);
}

multi method add-event-source(Vikna::EventEmitter:D $evs) {
    $.trace: "add-event-source for ", $evs.name;
    push @!event-source, $evs;
    $evs.init;
    my $evs-tap;
    $evs.Supply.tap:
        -> Event:D $ev {
            $.trace: "EVENT FROM SOURCE: ", $evs.name, ", ev object: ", $ev.WHICH, ", shutting down? ", $!event-shutdown, ":\n    ", $ev;
            self.dispatch: $ev unless $!event-shutdown;
        },
        tap => -> $tap { $evs-tap = $tap },
        done => { $evs-tap.close },
        quit => { $evs-tap.close };
}

# Pause event processing to allow 3rd party safely operate with the widget.
method queue-protect(&code) {
    $!ev-lock.protect: {
        &code()
    }
}

submethod DESTROY {
    .close with $!ev-queue;
}
