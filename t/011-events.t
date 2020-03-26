use v6.e.PREVIEW;
use Test;
use Vikna::EventHandling;
use Vikna::Events;
use Vikna::Object;

plan 2;

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

done-testing;
