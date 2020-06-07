use v6.e.PREVIEW;
use Test::Async;
use Vikna::EventHandling;
use Vikna::Events;
use Vikna::Object;
use Vikna::Utils;

plan 3;

class EvTest is Vikna::Event {
    has $.num;

    my $counter = 0;

    submethod TWEAK(*%c) {
        $!num = $counter++ unless %c<num>:exists;
    }

    submethod reset { $counter = 0 }
}
class EvDone is Vikna::Event { }

class EvObj is Vikna::Object does Vikna::EventHandling {
    has Promise:D $.dn .= new;
    has @.counts is rw;

    multi method event(EvTest $ev) {
        @.counts.push: $ev.num
    }
    multi method event(EvDone $ev) {
        $!dn.keep(True);
    }
}

sub await-tout(+@p) {
    await Promise.anyof: Promise.in(10), |@p
}

subtest "Basic dispatching" => {
    plan 1;

    my $inst = EvObj.new;
    for ^10 {
        $inst.dispatch: EvTest, num => $_
    }
    $inst.dispatch: EvDone;
    await-tout $inst.dn;

    is-deeply $inst.counts, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "all events received and are in order";
}

subtest "Subscriptions" => {
    plan 3;
    my @inst;
    for ^2 {
        @inst.push: EvObj.new;
    }

    my class EvObjU is EvObj {
        multi method subscription-event(EvTest $ev) {
            self.event: $ev;
            if $ev.num == 4 {
                self.unsubscribe(@inst[0]);
            }
        }
    }

    @inst[2] = EvObjU.new;

    # Test subscribe with code object
    @inst[1].subscribe(@inst[0], { @inst[1].event: $_ } );
    # Default will dispatch to subscriptio-event
    @inst[2].subscribe(@inst[0]);

    for ^10 {
        @inst[0].dispatch: EvTest, num => $_;
    }
    @inst[0].dispatch: EvDone;
    await-tout |@inst[0,1].map: { .dn };

    is-deeply @inst[0].counts, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "all events received and are in order for the initial object";
    is-deeply @inst[1].counts, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "all events received and are in order for the first subscriber";
    is-deeply @inst[2].counts, [0, 1, 2, 3, 4], "unsubscribing cut off last event for the second subscriber";
}

subtest "Tracing" => {
    plan 2;

    my class Event::Trace::First is Event {}
    my class Event::Trace::Second is Event {}
    my class Event::Trace::Third is Event {}
    my class Event::Trace::None is Event {}

    my class EvObjTrace is EvObj {
        has Promise:D $.done .= new;
        has $.tracer = "test-tracing";
        has $.suite;

        method start-trace {
            $!done .= new;
            $!tracer = 42;
            tag-event 42 => {
                self.dispatch: Event::Trace::First;
            }
        }

        multi method event(Event::Trace::First:D $ev) {
            $!suite.ok: ($!tracer ∈ $ev.tags), "first event has the tag set";
            tag-event "second", {
                self.dispatch: Event::Trace::Second;
            }
        }
        multi method event(Event::Trace::Second:D $ev) {
            $!suite.ok: ($!tracer ∈ $ev.tags), "second event get its tracer tag from the first one";
            $!suite.ok: ("second" ∈ $ev.tags), "second event got its second tag from tag-event";
            # Thread.start is the only way to guarantee cut off of dynamic context
            Thread.start: flow-branch {
                self.dispatch: Event::Trace::Third;
            }
        }
        multi method event(Event::Trace::Third:D $ev) {
            $!suite.ok: ($!tracer ∈ $ev.tags), "event dispatched within in-context flow inherits the trace tag";
            $!suite.ok: ("second" ∈ $ev.tags), "event dispatched within in-context flow inherits the second tag";
            Thread.start: {
                self.dispatch: Event::Trace::None;
            }
        }
        multi method event(Event::Trace::None:D $ev) {
            $!suite.nok: $ev.tags, "event dispatched within plain flow doesn't get tags";
            $!done.keep;
        }
    }

    subtest "seed with tag-event" => -> $suite {
        plan 6;
        my $obj = EvObjTrace.new: :$suite;
        $obj.dispatch: Event::Trace::First, :tags(set $obj.tracer);
        await-tout $obj.done;
    }
    subtest "seed with tag-event" => -> $suite {
        plan 6;
        my $obj = EvObjTrace.new: :$suite;
        $obj.start-trace;
        await-tout $obj.done;
    }
}

done-testing;
