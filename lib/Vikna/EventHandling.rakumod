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
    react {
        $.debug: "Started event handling on ", self.WHICH;
        whenever $!ev-queue -> $ev {
            $!ev-lock.protect: {
                $.debug: "REACTING ON EVENT: ", $ev.WHICH;
                self.handle-event($ev);
            }
            done if $!shutdown;
            CATCH {
                default {
                    note "EVENT KABOOM!";
                    $.debug: "EVENT HANDLING THROWN ", .message, .backtrace;
                    unless self.?on-event-queue-fail($_) {
                        note "[", $*THREAD.id, "] ", $_, $_.backtrace;
                        $!ev-queue.fail($_) if $!ev-queue;
                        self.stop-event-handling;
                        .rethrow;
                    }
                }
            }
        }
        CLOSE {
            $!events.done;
        }
    }
}

method start-event-handling(::?CLASS:D:) {
    $!ev-lock.protect: {
        unless $!ev-queue {
            $!ev-queue = Channel.new;
            start self!run-ev-loop;
        }
    }
}

method stop-event-handling {
    $!shutdown = True;
}

method handle-event(Event:D $ev) {
    # Make sure only one event is being handled at a time.
    $.debug: "HANDLING ", $ev.WHICH, " on ", self.^name;
    self.event($ev);
    $.debug: "EMITTING EVENT for subscribers: ", $ev.WHICH;
    start $!events.emit: $ev;
    $.debug: "EMITTED EVENT for subscribers: ", $ev.WHICH;
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
    $.debug: "SEND-EVENT: ", $ev.^name;
    self.throw: X::Event::Stopped, :$ev if $!shutdown;
    my Vikna::Event:D @events = $ev;
    $!send-lock.protect: {
        $.debug: " ---> FILTERING EVENT";
        @events = $_ with self.event-filter($ev);
        $.debug: " ---> FILTERED EVENTS:\n",
                    @events.map( { "      . " ~ .^name } ).join("\n");
    }
        for @events -> $filtered {
            $.debug: " ---> QUEUEING ", $filtered.WHICH;
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
                $.handle-event: $filtered
            }
        }
        $ev
}

multi method dispatch(Vikna::Event:D $ev) {
    $.send-event: $ev.clone(:dispatcher($ev.dispatcher));
}

multi method dispatch(Vikna::Event:U \EvType, *%params) {
    $.debug: "NEW EVENT OF ", EvType.^name, " with ", %params;
    $.send-event: self.create(EvType, :dispatcher( self ), |%params );
}

# Preserve event's dispatcher. send-event sugar, for readability.
method re-dispatch(Vikna::Event:D $ev) {
    $.send-event: $ev
}

sub ev2key($ev) { $ev.WHICH }

proto method event(Event:D $ev) {*}
multi method event(Event:D $ev) { #`<Sink method> }

proto method event-filter(Event:D) {*}
multi method event-filter(Event:D $ev) { [$ev] }

submethod DESTROY {
    .close with $!ev-queue;
}
