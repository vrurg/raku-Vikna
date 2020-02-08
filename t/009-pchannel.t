use v6.e.PREVIEW;
use Test;
use Vikna::PChannel;

plan 2;

subtest "Count messages" => {
    plan 1;
    my $pc = Vikna::PChannel.new;

    my atomicint $counter = 0;

    # start readers
    my @rp;
    for ^10 {
        @rp.push: start {
            my $done;
            until $done {
                my $v = $pc.receive;
                if $v ~~ Failure {
                    $v.so;
                    $done = True;
                }
                else {
                    ++⚛$counter;
                }
            }
        }
    }

    my @sp;
    for ^10 -> $prio {
        @sp.push: start {
            for ^10 -> $val {
                $pc.send: $prio * 10 + $val, $prio;
            }
        }
    }
    await @sp;
    $pc.close;
    await @rp;

    is $counter, 100, "all packets passed";
}

# See if sending concurrently with different priorities we eventually get data in the orider of higher -> lower priority
# and the sending order withing priority is preserved.
subtest "Ordering" => {
    plan 3;

    my $pc = Vikna::PChannel.new;
    my @prio-ready = Promise.new xx 3;

    my @p;
    for ^3 -> $prio {
        @p.push: start {
            for ^100 -> $val {
                $pc.send: $prio × 100 + $val, $prio;
            }
            @prio-ready[$prio].keep(True);
        }
    }

    @p.push: start {
        for 2...0 -> $prio {
            await @prio-ready[$prio];
            my @list;
            for ^100 {
                @list.push: $pc.receive;
            }
            is-deeply @list, (^100).map( * + $prio × 100 ).Array, "prio $prio came in the order";
        }
    }

    await @p;
}

done-testing;
