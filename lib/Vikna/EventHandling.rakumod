use v6.e.PREVIEW;
unit role Vikna::EventHandling;
use Vikna::Events;
use Vikna::Utils;
use AttrX::Mooish;
use Vikna::X;

has Supplier:D $.events .= new;

has Lock::Async:D $!ev-lock .= new;
has Lock::Async:D $!send-lock .= new;

has Channel $!ev-queue;
has %!subscriptions;

has Bool:D $!shutdown = False;

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
                $.trace: "EVENT ", $ev.WHICH, " START HANDLING", :event;
                self.handle-event($ev);
                $.trace: "EVENT ", $ev.WHICH, " HANDLING DONE", :event;
            }
            done if $!shutdown;
            CATCH {
                default {
                    note "EVENT KABOOM!";
                    note .message, ~.backtrace;
                    $.trace: "EVENT HANDLING THROWN:\n", .message, .backtrace, :error;
                    unless self.?on-event-queue-fail($_) {
                        note "[", $*THREAD.id, "] ", $_, $_.backtrace;
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
            $.flow: { self!run-ev-loop }, :name('EVENT LOOP ' ~ self.WHICH);
        }
    }
}

method stop-event-handling(::?ROLE:D:) {
    $!shutdown = True;
}

method handle-event(::?ROLE:D: Event:D $ev) {
    # Make sure only one event is being handled at a time.
    $.trace: "HANDLING ", $ev.WHICH, :event;
    self.event($ev);
    $.trace: "EMITTING EVENT for subscribers: ", $ev.WHICH, :event;
    $.flow: { $!events.emit: $ev }, :name('EVENT SUBSCRIBERS ' ~ self.WHICH);
    $.trace: "EMITTED EVENT for subscribers: ", $ev.WHICH, :event;
}

method subscribe(::?ROLE:D $obj, &code?) {
    %!subscriptions{ $obj } = $obj.events.Supply.tap: &code // { self.handle-event: $_ };
}

method unsubscribe(::?ROLE:D $obj) {
    with %!subscriptions{ $obj }:delete {
        .close;
    } else {
        self.throw: X::Event::Unsubscribe, :$obj
    }
}

method send-event(Vikna::Event:D $ev) {
    $.trace: "SEND-EVENT: ", $ev.WHICH, :event;
    self.throw: X::Event::Stopped, :$ev if $!shutdown;
    my Vikna::Event:D @events = $ev;
    $!send-lock.protect: {
        $.trace: "  ---> FILTERING EVENT";
        @events = $_ with self.event-filter($ev);
        $.trace: "  ---> FILTERED EVENTS:\n",
                    @events.map( { "      . " ~ .WHICH } ).join("\n"), :event;
    }
    for @events -> $filtered {
        $.trace: " ---> QUEUEING ", $filtered.WHICH, :event;
        # If event queue is not initialized then work synchronously.
        if $!ev-queue {
            $!ev-queue.send: $filtered;
            CATCH {
                when X::Channel::SendOnClosed {
                    self.throw: X::Event::Stopped, ev => $filtered;
                }
            }
        }
        else {
            $.flow: { $.handle-event: $filtered }, :sync, :name('SYNC EVENT HANDLING');
        }
    }
    $ev
}

multi method dispatch(::?ROLE:D: Vikna::Event:D $ev) {
    $.send-event: $ev.clone(:dispatcher($ev.dispatcher));
}

multi method dispatch(::?ROLE:D: Vikna::Event:U \EvType, *%params) {
    my $ev = self.create(EvType, :dispatcher( self ), |%params );
    $.trace: "NEW EVENT ", $ev.WHICH, " with params:\n", %params.pairs».map("  " ~ *).join("\n");
    $.send-event: $ev;
}

# Preserve event's dispatcher. send-event sugar, for readability.
method re-dispatch(::?ROLE:D: Vikna::Event:D $ev) {
    $.send-event: $ev
}

sub ev2key($ev) { $ev.WHICH }

proto method event(::?ROLE:D: Event:D $ev) {*}
multi method event(::?ROLE:D: Event:D $ev) { #`<Sink method> }

proto method event-filter(::?ROLE:D: Event:D) {*}
multi method event-filter(::?ROLE:D: Event:D $ev) { [$ev] }

submethod DESTROY {
    .close with $!ev-queue;
}
