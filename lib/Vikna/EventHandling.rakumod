use v6.e.PREVIEW;

unit role Vikna::EventHandling;

use Vikna::Events;
use Vikna::Utils;
use Vikna::EventEmitter;
use AttrX::Mooish;
use Vikna::X;

has Supplier:D $.events .= new;

has Lock::Async:D $!ev-lock .= new;
has Lock::Async:D $!send-lock .= new;

has Channel $!ev-queue;
has %!subscriptions;

has @!event-source;

has Bool:D $!event-shutdown = False;

submethod TWEAK {
    self.start-event-handling
}

method !run-ev-loop {
    my $vf = $*VIKNA-FLOW;
    $.trace: "Starting event handling", :event;
    react {
        whenever $!ev-queue -> $ev {
            my $*VIKNA-FLOW = $vf; # Preserve the flow
            $!ev-lock.protect: {
                if $!event-shutdown {
                    $.trace: "EVENT QUEUE SHUTDOWN, dropping event ", $ev;
                    self.?drop-event($ev);
                }
                else {
                    $.trace: "START HANDLING ", $ev, :event;
                    my $ev-handled = Promise.new;
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
                    $ev.dispatcher.handle-event($ev);
                    $ev-handled.keep(True);
                    $.trace: "EVENT ", $ev, " HANDLING DONE", :event;
                }
            }
            CATCH {
                default {
                    note "EVENT KABOOM on {self.?name // self.WHICH}! ", .message, ~.backtrace;
                    $.trace: "EVENT HANDLING THROWN:\n", .message, .backtrace, :error;
                    unless self.?on-event-queue-fail($_) {
                        $!ev-queue.fail($_) if $!ev-queue;
                        self.stop-event-handling;
                        $.trace: "RETHROWING ", $_.WHICH;
                        .rethrow
                    }
                }
            }
        }
        CLOSE {
            $!events.done;
        }
    }
}

method start-event-handling(::?ROLE:D:) {
    $!ev-lock.protect: {
        unless $!ev-queue {
            $!ev-queue = Channel.new;
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
    CATCH { when X::Channel::SendOnClosed { .resume } }

    .shutdown for @!event-source;
    # Unsubscribe from all.
    .close for %!subscriptions.values;
    .send: my $nop = $.create: Event::Cmd::Nop, :dispatcher( self ) with $!ev-queue;
    $nop ?? $nop.completed !! Promise.kept(True)
}

method handle-event(::?ROLE:D: Event:D $ev) {
    # Make sure only one event is being handled at a time.
    $.trace: "HANDLING ", $ev, :event;
    self.event($ev);
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

method send-event(Vikna::Event:D $ev) {
    $.trace: "SEND-EVENT: ", $ev, :event;
    self.throw: X::Event::Stopped, :$ev if $!event-shutdown;
    my Vikna::Event:D @events = $ev;
    $!send-lock.protect: {
        $.trace: "FILTERING EVENT ", $ev;
        @events = $_ with $ev.dispatcher.?event-filter($ev);
        $.trace: "FILTERED EVENTS:\n", @events.join("\n"), :event;
    }
    for @events -> $filtered {
        # If event queue is not initialized then work synchronously.
        if $!ev-queue {
            $.trace: "QUEUEING ", $filtered, :event;
            $!ev-queue.send: $filtered;
            CATCH {
                when X::Channel::SendOnClosed {
                    self.throw: X::Event::Stopped, ev => $filtered;
                }
            }
        }
        else {
            $.trace: "DIRECT HANDLING ", $filtered, :event;
            $ev.dispatcher.handle-event: $filtered;
            # $.flow: { $ev.dispatcher.handle-event: $filtered }, :sync, :name('SYNC EVENT HANDLING ' ~ self.name);
        }
    }
    $ev
}

proto method dispatch(::?ROLE:D: Event, |) {*}

multi method dispatch(::?ROLE:D: Event:D $ev) {
    $.send-event( self === $ev.dispatcher ?? $ev !! $ev.clone(:dispatcher(self)) );
}

multi method dispatch(::?ROLE:D: Vikna::Event:U \EvType, *%params) {
    my $ev = $.create: EvType, :origin(self), :dispatcher(self), |%params;
    $.trace: "NEW EVENT ", $ev, " with params:\n", %params.pairs».map({ "  " ~ .key ~ " => " ~ (.value // '*undef*') }).join("\n");
    $.dispatch: $ev;
}

# Preserve event's dispatcher. send-event sugar, for readability.
method re-dispatch(::?ROLE:D: Vikna::Event:D $ev) {
    $.send-event: $ev
}

proto method event(::?ROLE:D: Event:D $ev) {*}
multi method event(::?ROLE:D: Event:D $ev) { #`<Sink method> }

proto method event-filter(::?ROLE:D: Event:D) {*}
multi method event-filter(::?ROLE:D: Event:D $ev) { [$ev] }

multi method add-event-source(Vikna::EventEmitter:U \evs-type, |c) {
    $.add-event-source: $.create(evs-type, |c);
}

multi method add-event-source(Vikna::EventEmitter:D $evs) {
    push @!event-source, $evs;
    $evs.init;
    my $evs-tap;
    $evs.Supply.tap:
        -> Event:D $ev {
            $.trace: "EVENT FROM SOURCE: ", $evs.WHICH, ":\n    ", $ev;
            self.dispatch: $ev unless $!event-shutdown;
        },
        tap => -> $tap { $evs-tap = $tap },
        done => { $evs-tap.close },
        quit => { $evs-tap.close };
}

submethod DESTROY {
    .close with $!ev-queue;
}
