use v6;
unit role Vikna::Test::EventSequencer;

use AttrX::Mooish;
use Vikna::Events;
use Test::Async::Hub;

has Supplier:D $.ev-supply .= new;
has $.timeout = 30;


method is-event-sequence(Iterable:D $task-list, Str $message, :$timeout = $.timeout --> Promise:D) {
    # Have we pulled everything from $ev-iter?
    my $test-completed = Promise.new;
    my $completion-vow = $test-completed.vow;
    my $sequence-completed = Promise.new;

    # If user callback returns and iterator, push the previous one on the stack.
    my @iter-stack;

    # List of EvRecord instances.
    my @results;

    my $ev-iter = $task-list.iterator;

    # Current iterator we use for pulling tasks.
    my $cur-iter = $ev-iter;

    # EvRecord instance we're currently working with.
    my $cur-rec;

    my $status-lock = Lock.new;

    my sub sequence-failed {
        $status-lock.protect: {
            $cur-rec.fail;
            $sequence-completed.keep(False)
                if $sequence-completed.status ~~ Planned;
        }
    }

    my sub sequence-succeed {
        $status-lock.protect: {
            $sequence-completed.keep(True)
                if $sequence-completed.status ~~ Planned;
        }
    }

    my sub push-iterator($new-iter) {
        @iter-stack.push: $cur-iter;
        $cur-iter = $new-iter;
    };

    my sub pop-iterator {
        return Nil unless +@iter-stack;
        $cur-iter = @iter-stack.pop
    };

    my sub next-record {
        my $task;
        $*ERR.print: "(next)";
        repeat {
            $task := $cur-iter.pull-one;
            note "GOT TASK: ", $task.WHICH;
            if $task =:= IterationEnd {
                note "ITER END";
                unless pop-iterator() {
                    sequence-succeed;
                    return Nil
                }
            }
        } until $task;

        note "TASK: ", $task.WHICH;

        $cur-rec = EvRecord.new: |$task;
        @results.push: $cur-rec;

        Promise.anyof(
            $cur-rec.completed,
            Promise.in($timeout).then({
                note "TIMEOUT!";
                $cur-rec.fail(:comment("Timed out after $timeout sec"));
                sequence-failed;
            })
        )
    }

    start {
        next-record;
        react {
            whenever $!ev-supply -> $ev {
                note "EVENT FOR PROCESSING: $ev";
                if $cur-rec.match($ev) {
                    note "MATCHED, passed: ", $cur-rec.passed;
                    my $cb-ret = .($ev, $cur-rec) with $cur-rec.callback;
                    if $cur-rec.passed {
                        if $cb-ret ~~ Iterable {
                            push-iterator($cb-ret.iterator);
                        }
                        next-record;
                    }
                    else {
                        sequence-failed;
                    }
                }
            }
            whenever $sequence-completed -> $passed {
                self!report-status(@results, $message);
                $completion-vow.keep($passed);
                done
            }
        }
    }
    $test-completed
}

proto method event(Event:D) {*}
multi method event(Event:D $ev) {
    my $rc = callsame;
    $!ev-supply.emit: $ev;
    $rc
}

method !report-status(@results, $message) {
    Test::Async::Hub.test-suite.subtest: $message => -> \suite {
        suite.plan: 2 * @results;
        for @results {
            suite.ok: .passed, .message;
            suite.diag: .comment if !.passed && .comment;
        }
    }
}
