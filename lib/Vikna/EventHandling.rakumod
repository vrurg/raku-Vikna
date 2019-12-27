use v6.e.PREVIEW;
unit role Vikna::EventHandling;
use Vikna::Events;
use Vikna::Utils;
use AttrX::Mooish;
use Vikna::X;

my class HoldEntry {
    has Mu $.ev-type is required;
    has EvHoldKind:D $.kind is required;
    has @.queue;

    method add(Event:D $ev) {
        given $!kind {
            when HoldCollect {
                @!queue.push: $ev;
            }
            when HoldLast {
                @!queue[0] = $ev;
            }
            when HoldFirst {
                @!queue[0] = $ev unless @!queue;
            }
        }
    }
}

has Supplier:D $.events .= new;

has Channel:D $!ev-queue = Channel.new;
has %!subscriptions;

has %!holds;
has $!hold-lock = Lock.new;

submethod TWEAK {
    self!run-event-handling;
}

method !run-event-handling(::?CLASS:D:) {
    start react {
        $.debug: "Started event handling";
        whenever $!ev-queue -> $ev {
            if !self!event-on-hold($ev) {
                self.?event($ev);
                $!events.emit: $ev
            }
            CATCH {
                default {
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

method subscribe(::?ROLE:D $obj, &code?) {
    %!subscriptions{ $obj } = $obj.events.Supply.tap: &code // { self.event: $_ }
}

method unsubscribe(::?ROLE:D $obj) {
    with %!subscriptions{ $obj }:delete {
        .close;
    } else {
        self.throw: X::Event::Unsubscribe, :$obj
    }
}

multi method dispatch(Vikna::Event:D $ev) {
    $!ev-queue.send: $ev.clone(:dispatcher($ev.dispatcher));
    $ev
}

multi method dispatch(Vikna::Event:U \EvType, *%params) {
    self.dispatch: self.create(EvType, :dispatcher( self ), |%params );
}

sub ev2key($ev) { $ev.WHICH }

multi method hold-events(Event \evt, EvHoldKind:D :$kind = HoldCollect) {
    my $ev-type := evt.WHAT;

    self.throw: X::Event::Unholdable, :ev($ev-type) if $ev-type ~~ Event::Unholdable;

    $!hold-lock.protect: {
        my $ev-key = ev2key($ev-type);
        # self.throw: X::Event::AlreadyHeld, :ev($ev-type) if %!holds{$ev-key}:exists;
        %!holds{$ev-key}.push: self.create: HoldEntry, :$ev-type, :$kind;
        self.dispatch: Event::HoldAcquire, :$ev-type;
    }
}

multi method hold-events(Event \evt, &code, EvHoldKind:D :$kind = HoldCollect) {
    self.hold-events(evt, :$kind);
    LEAVE self.release-events(evt);
    &code()
}

method release-events(Event \evt) {
    $!hold-lock.protect: {
        my $ev-type = evt.WHAT;
        my $ev-key = ev2key($ev-type);
        self.throw: X::Event::NotHeld, :ev($ev-type) unless %!holds{$ev-key}:exists && %!holds{$ev-key}.elems;
        my $hentry = %!holds{$ev-key}.pop;
        for $hentry.queue -> $ev {
            self.dispatch: $ev
        }
        self.dispatch: Event::HoldRelease, :$ev-type;
    }
}

method sync-events( --> Promise:D ) {
    self.dispatch(Event::SyncQueue).promise
}

proto method event(Event:D $ev) {*}
multi method event(Event::SyncQueue:D $ev) {
    $ev.promise.keep(True) if $ev.origin === self;
}
multi method event(Event:D $ev) {
    # Sink method
}

method !event-on-hold(Event:D $ev) {
    $!hold-lock.protect: {
        my $ev-key = ev2key($ev.WHAT);
        my $held = False;
        with %!holds{$ev-key} {
            if $_.elems {
                $_[*-1].add: $ev;
                $held = True;
            }
        }
        $held
    }
}

submethod DESTROY {
    $!ev-queue.close;
}
