use v6.e.PREVIEW;

unit role Vikna::EventHandling;

use Vikna::Events;
use Vikna::Utils;
use Vikna::EventEmitter;
use Vikna::PChannel;
use AttrX::Mooish;
use Vikna::X;

has Supplier:D $.events .= new;

has Lock::Async:D $!ev-lock .= new;
has Lock::Async:D $!send-lock .= new;

has Vikna::PChannel $!ev-queue;
has %!subscriptions;

has @!event-source;

has Bool:D $!event-shutdown = False;

submethod TWEAK {
    self.start-event-handling
}

method !run-ev-loop {
    $.trace: "Starting event handling", :event;
    loop {
        my $ev = $!ev-queue.receive;
        if $ev ~~ Failure {
            if $ev.exception ~~ X::PChannel::ReceiveOnClosed {
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
        CATCH {
            default {
                note "===EVENT KABOOM=== on {self.?name // self.WHICH}! ", .message, ~.backtrace;
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
    $!events.done;
}

method start-event-handling(::?ROLE:D:) {
    $!ev-lock.protect: {
        unless $!ev-queue {
            $!ev-queue = Vikna::PChannel.new;
            $.flow: { self!run-ev-loop }, :name('EVENT LOOP ' ~ (self.?name // self.WHICH));
        }
    }
    $.dispatch: Event::Init;
}

method stop-event-handling(::?ROLE:D:) {
    LEAVE {
        $!event-shutdown = True;
        .close with $!ev-queue;
    }
    # Ignore closed channel on shutdown as it might be caused by a panic exit and we don't want to add to the bail-out
    # noise.
    CATCH {
        when X::Channel::SendOnClosed { }
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

method handle-event(::?ROLE:D: Event:D $ev) {
    # Make sure only one event is being handled at a time.
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

method send-event(Vikna::Event:D $ev, EventPriority $priority?) {
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
            $.trace: "QUEUEING(prio:{($priority // $filtered.priority).Int}) ", $filtered, :event;
            $!ev-queue.send: $filtered, ($priority // $filtered.priority).Int;
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

multi method dispatch(::?ROLE:D: Event:D $ev, EventPriority $priority?) {
    $.send-event( self === $ev.dispatcher ?? $ev !! $ev.clone(:dispatcher(self)), $priority );
}

multi method dispatch(::?ROLE:D: Vikna::Event:U \EvType, EventPriority $priority?, *%params) {
    my %defaults = :origin(self), :dispatcher(self);
    %defaults.append: :$priority if $priority.defined;
    my $ev = $.create: EvType, |%defaults, |%params;
    $.trace: "NEW EVENT ", $ev, " with params:\n", %params.pairs».map({ "  " ~ .key ~ " => " ~ (.value // '*undef*') }).join("\n");
    $.dispatch: $ev;
}

# Preserve event's dispatcher. send-event sugar, for readability.
method re-dispatch(::?ROLE:D: Vikna::Event:D $ev) {
    $.send-event: $ev
}

proto method send-command(|) {
    {*}
}
multi method send-command(Event::Command:U \evType, |args) {
    CATCH {
        when X::Event::Stopped {
            .ev.completed.break($_);
            return .ev
        }
        default {
            .rethrow;
        }
    }
    self.dispatch: evType, :args(args);
}

proto method drop-event(::?CLASS:D: Event:D)  {*}
multi method drop-event(Event::Command:D $ev) {
    $.trace: "DROPPING ", $ev;
    $ev.complete(X::Event::Dropped.new( :obj(self), :$ev ) but False);
}
multi method drop-event(Event:D)              { }

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
