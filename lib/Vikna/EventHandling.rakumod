use v6.e.PREVIEW;
unit role Vikna::EventHandling;
use Vikna::Events;
use Vikna::Utils;
use AttrX::Mooish;
use Vikna::X;

has Supplier:D $.events .= new;

has Lock::Async:D $!ev-lock .= new;
has Lock::Async:D $!send-lock .= new;

has Channel:D $!ev-queue = Channel.new;
has %!subscriptions;

has Bool:D $!shutdown = False;

submethod TWEAK {
    self!run-event-handling;
}

method !run-event-handling(::?CLASS:D:) {
    start react {
        $.debug: "Started event handling on ", self.WHICH;
        whenever $!ev-queue -> $ev {
            $.debug: "REACTING ON EVENT: ", $ev.WHICH;
            self.handle-event($ev);
            $.debug: "EMITTING EVENT for subscribers: ", $ev.WHICH;
            start $!events.emit: $ev;
            $.debug: "EMITTED EVENT for subscribers: ", $ev.WHICH;
            done if $!shutdown;
            CATCH {
                default {
                    note "EVENT KABOOM!";
                    $.debug: "EVENT HANDLING THROWN ", .message, .backtrace;
                    unless self.?on-event-queue-fail($_) {
                        note "[", $*THREAD.id, "]", $_, $_.backtrace;
                        $!ev-queue.fail($_);
                    }
                }
            }
        }
        CLOSE {
            $!events.done;
        }
    }
}

method handle-event(Event:D $ev) {
    # Make sure only one event is being handled at a time.
    $!ev-lock.protect: {
        $.debug: "Handling ", $ev.WHICH, " on ", self.^name;
        self.event($ev);
        $.debug: "Handled ", $ev.WHICH, " on ", self.^name;
    }
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
    if $ev ~~ Event::Cmd::Redraw {
        $.debug: " ... redraw event has ", $ev.invalidations.elems, " invalidations";
    }
    $!send-lock.protect: {
        my Vikna::Event:D @events = $ev;
        @events = $_ with self.event-filter($ev);
        $.debug: " ---> FILTERED EVENTS:\n",
                    @events.map( { "      . " ~ .^name } ).join("\n");
        for @events {
            $.debug: " ---> QUEUEING ", $_.WHICH;
            $!ev-queue.send: $_
        }
        $ev
    }
}

multi method dispatch(Vikna::Event:D $ev) {
    $.send-event: $ev.clone(:dispatcher($ev.dispatcher));
}

multi method dispatch(Vikna::Event:U \EvType, *%params) {
    $.debug: "NEW EVENT OF ", EvType.^name, " with ", %params;
    $.send-event: self.create(EvType, :dispatcher( self ), |%params );
}

# Preserve event's dispatcher. Sugar for readability.
method re-dispatch(Vikna::Event:D $ev) {
    $.send-event: $ev
}

sub ev2key($ev) { $ev.WHICH }

proto method event(Event:D $ev) {*}
multi method event(Event:D $ev) { #`<Sink method> }

proto method event-filter(Event:D) {*}
multi method event-filter(Event:D $ev) { [$ev] }

method shutdown-events {
    $!shutdown = True;
}

submethod DESTROY {
    $!ev-queue.close;
}
