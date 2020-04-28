use v6;

unit role Vikna::Test::EventSequencer {
    has Supplier:D $.ev-supply .= new;

    my class EvRecord {
        has $.type is built(:bind);
        has Promise:D $.completed .= new;
        has Lock:D $!complete-lock .= new;
        # Must return True if event is to be accepted for matching. Allows to not react on irrelevant events of same
        # type.
        has &.accept;
        # Must return True if matching event is passing user conditions; i.e. it's matching.
        has &.checker;
        # Something we wanna do when matching is done. Called always, no matter if matching succeed or failed. Receives
        # event and EvRecord instances. Can be used to initiate next action on a widget.
        has &.callback;
        has $.origin is built(:bind) = Nil;
        has $.dispatcher is built(:bind) = Nil;
        has Str $.message is mooish(:lazy);
        has Str $.comment;

        method build-message {
            "event " ~ $!type.^name
                ~ ($!origin !=== Nil ?? " orig=" ~ $!origin !! "")
                ~ ($!dispatcher !=== Nil ?? " disp=" ~ $!dispatcher !! "")
        }

        method !match-widget(Mu \a, Mu \b) {
            return True if b === Nil;
            b.defined ?? (a === b) !! (a ~~ b)
        }

        method !checker-ok($ev) {
            &!checker.defined ?? &!checker($ev) !! True
        }

        method !event-accepted($ev) {
            &!accept ?? &!accept($ev) !! True
        }

        method comment-widget-match(\got, \expected, $kind) {
            $!comment = "Event $kind doesn't match.\n"
                        ~ "  expected: " ~ expected.WHICH
                        ~ "       got: " ~ got.WHICH
        }

        # The method returns True if event type is matching and &!accept callback confirms acceptance.
        # Returned False means that event has been skipped.
        method match(Event:D $ev) {
            if $ev ~~ $!type && self!event-accepted($ev) {
                my $passed = False;
                if ! self!match-widget($ev.origin, $!origin) {
                    self.comment-widget-match($ev.origin, $!origin, 'origin')
                }
                elsif ! self!match-widget($ev.dispatcher, $!dispatcher) {
                    self.comment-widget-match($ev.dispatcher, $!dispatcher, 'dispatcher')
                }
                elsif ! self!checker-ok($ev) {
                    $!comment = "User supplied checker doesn't pass for event " ~ $ev;
                }
                else {
                    $passed =True;
                }
                self!set-status($passed);
                return True
            }
            False;
        }

        method !set-status($passed, :$comment?) {
            $!complete-lock.protect: {
                if $!completed.status ~~ Planned {
                    $passed
                        ?? $!completed.keep(self)
                        !! $!completed.break(self);
                    $!comment = $_ with $comment;
                }
            }
        }

        method fail(*%c) { self!set-status(False, |%c) }
        method success   { self!set-status(True)  }

        method passed { $!completed.status ~~ Kept }
    }

    method is-event-sequence(Iterable:D $task-list, Str $message, :$timeout = $!timeout --> Promise:D) {
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
        subtest $message => {
            for @results {
                ok .passed, .message;
                diag .comment if !.passed && .comment;
            }
        }
    }
}
