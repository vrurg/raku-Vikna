use v6.e.PREVIEW;
    ;

use Test::Async::Decl;

unit test-bundle Vikna::Test;

use Vikna::Canvas;
use Vikna::Rect;
use Vikna::Widget;
use Vikna::Events;
use Vikna::WAttr;
use AttrX::Mooish;
use Test::Async::Hub;
use Test::Async::Decl;
use Test::Async::Utils;

# Default timeout for some tests
has Numeric:D $.vikna-timeout where * > 0 = 5;

method setup-from-plan(%plan) {
    callsame;
    $!vikna-timeout = $_ with %plan<vikna-timeout>:delete;
}

my role EvReporter {
    has Supplier:D $.ev-postproc .= new;
    submethod TWEAK(|) {
        self.events.Supply.tap: done => { $!ev-postproc.done };
    }
    proto method event(Event:D) {*}
    multi method event(Event:D $ev) {
        my $rc = callsame;
        $rc .= List if $rc ~~ Slip;
#        note "-- $ev";
        $!ev-postproc.emit: [$ev, $rc];
        $rc
    }
}
my class SeqTask {
    has $.type is built(:bind);
    has Promise:D $.completed .= new;
    has $!completed-vow = $!completed.vow;
    has Lock::Async:D $!complete-lock .= new;
    has Int:D $.timeout is required;
    has Promise $.tout-promise;
    has Test::Async::Hub:D $.suite is required;
    # Must return True if event is to be accepted for matching. Allows to not react on irrelevant events of same
    # type.
    has &.accept;
    # Must return True if matching event is passing user conditions; i.e. it's matching.
    has &.checker;
    # Something we wanna do when matching is done. Called always, no matter if matching succeed or failed. Receives
    # event and SeqTask instances. Can be used to initiate next action on a widget.
    has &.on-match;
    # What task status is set.
    has &.on-status;
    has $.origin is built(:bind) = Nil;
    has $.dispatcher is built(:bind) = Nil;
    has Str $.message is mooish(:lazy);
    has Str $.comment;

    submethod TWEAK(|) {
        $!tout-promise = Promise.anyof($!completed, Promise.in($!timeout).then: {
            # Only fail if task haven't completed.
            $!complete-lock.protect: {
                if $!completed.status ~~ Planned {
                    $!suite.flunk: $!message;
                    $!suite.diag: "Timed out after $!timeout sec";
                    self!set-status: False;
                }
            }
        })
    }

    method build-message {
        "event " ~ $!type.^name ~ ($!origin !=== Nil ?? " orig=" ~ $!origin !! "") ~ ($!dispatcher !=== Nil ?? " disp=" ~ $!dispatcher !! "")
    }

    method !match-widget(Mu \a, Mu \b) {
        return True if b === Nil;
        b.defined ?? (a === b) !! (a ~~ b)
    }

    method !checker-ok($ev) {
        return .($ev, self) with &!checker;
        True
    }

    method !event-accepted($ev) {
        return .($ev, self) with &!accept;
        True
    }

    method comment-widget-match(\got, \expected, $kind) {
        "Event $kind doesn't match.\n" ~ "  expected: " ~ expected.WHICH ~ "       got: " ~ got.WHICH
    }

    # The method returns True if event type is matching and accept callback confirms acceptance.
    # Returned False means that event has been skipped.
    method match(Event:D $ev) {
#        note "'{$!message}' -- $ev";
        if $ev ~~ $!type && self!event-accepted($ev) {
            $!complete-lock.protect: {
                self!set-status:
                    await $.suite.subtest: :!async, :instant, :hidden, $!message, -> \stest {
                        # Can't set planned number because callbacks could do tests on their own
                        .($ev, self) with &!on-match;
                        stest.proclaim:
                            test-result(self!match-widget($ev.origin, $!origin),
                                fail => { comments => self.comment-widget-match($ev.origin, $!origin, 'origin') },),
                            "event origin";
                        stest.proclaim:
                            test-result(self!match-widget($ev.dispatcher, $!dispatcher),
                                fail => { comments => self.comment-widget-match($ev.dispatcher, $!dispatcher,
                                    'dispatcher') },), "event dispatcher";
                        stest.ok: self!checker-ok($ev), "event checker callback";
                    };
            }
            True
        }
        else {
            False
        }
    }

    method !set-status($passed) {
        # note "TASK '$!message' status: ", $!completed.status;
        if $!completed.status ~~ Planned {
            $!completed-vow.keep($passed);
            .($passed, self) with &!on-status;
        }
    }

    method passed {
        .status ~~ Planned ?? Nil !! .result with $!completed
    }
}

method is-event-sequence(Vikna::Widget:D $widget,
                         Iterable:D $task-list,
                         Str:D $message,
                         :$timeout = $!vikna-timeout,
                         :$async = False,
                         :%defaults) is test-tool {
    unless $widget ~~ EvReporter {
        $widget does EvReporter;
    }
    my $test-ready = Promise.new;
    my $test-promise = self.subtest: $message, :$async, :instant, :hidden, -> \suite {
        $test-ready.keep(True);

        # If user on-match callback returns an iterator, push the previous one on the stack.
        my @iter-stack;

        # Current iterator we use for pulling tasks.
        my $cur-iter = $task-list.iterator;

        # SeqTask instance we're currently working with.
        my $cur-task;

        my $stop-react = Promise.new;

        my sub push-iterator($new-iter) {
            @iter-stack.push: $cur-iter;
            $cur-iter = $new-iter;
        };

        my sub pop-iterator {
            return Nil unless +@iter-stack;
            $cur-iter = @iter-stack.pop
        };

        my sub next-task {
            my $task;
            repeat {
                $task := $cur-iter.pull-one;
                # note "GOT TASK: ", $task.WHICH;
                if $task =:= IterationEnd {
                    # note "ITER END";
                    unless pop-iterator() {
                        # Task list exhausted, sequencing succeeded
                        # note "*** TASK LIST EXHAUSTED";
                        $cur-task = Nil;
                        return Nil
                    }
                }
            } until $task;

            $cur-task = SeqTask.new: :dispatcher($widget), |%defaults, |$task, :$timeout, :suite(test-suite);

            $cur-task.completed.then: -> $p {
                CATCH { default {
                    note $_, ~$_.backtrace;
                    exit 255;
                } }
                my $passed = $p.status ~~ Kept;
                $stop-react.keep("cur-task") if $stop-react.status ~~ Planned && !$passed;
            }
            $cur-task
        }

        next-task;

        $widget.dismissed.then: {
            if $stop-react.status ~~ Planned {
                suite.flunk: $cur-task.message;
                suite.diag: 'Premature event queue shut down';
                $stop-react.keep("ev-queue done");
            }
        };

        react {
            whenever $widget.ev-postproc -> [$ev, $rc] {
                my $*TEST-SUITE = suite;
                if $cur-task.match($ev) {
                    $stop-react.keep("event-reader") unless $cur-task.passed && next-task;
                }
            }
            whenever $stop-react {
#                note "STOP REACT";
                done;
            }
        }
        #        if $cur-task && !$cur-task.passed {
        #            # Unprocessed task means it fails.
        #        }
    };
    await $test-ready;
    $test-promise
}

proto method is-rect-filled(|) is test-tool {*}
multi method is-rect-filled(Vikna::Canvas:D $canvas, Vikna::Rect:D $rect, Str:D $message, Vikna::WAttr :$attr, *%c) {
    my $matches = True;
    my @keys = <fg bg style>;
    with $attr {
        for @keys {
            %c{$_} //= $attr."$_"();
        }
        %c<char> //= $attr.pattern;
    }
    for %c.keys -> $key {
        unless Vikna::Canvas::Cell.^can($key) {
            self.diag: "WARNING: unknown key in profile: $key\n",
                       "         No such attribute on Vikna::Canvas::Cell";
        }
    }
    for $rect.x .. $rect.right -> $x {
        for $rect.y .. $rect.bottom -> $y {
            my $cell = $canvas.pick($x, $y);
            for %c.keys -> $key {
                next unless $cell.^can($key);
                unless $cell."$key"() eqv %c{$key} {
                    self.flunk: $message;
                    self.diag: "At pos $x, $y, attribute '$attr' doesn't match\n",
                        self.expected-got(%c{$key}.raku, $cell."$key"().raku);
                    return False
                }
            }
        }
    }
    self.pass: $message;
}
