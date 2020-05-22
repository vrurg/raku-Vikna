use v6.e.PREVIEW;
use Test::Async::Decl;
BEGIN require ::('Test::Async::X');
our constant Test-Async-X-Base = ::('Test::Async::X::Base');

class X::TaskCompleted is Test-Async-X-Base {
    has $.task;
    method message {
        "Match is not possible, task '" ~ $!task.message ~ "' is completed"
    }
}

our test-bundle Vikna::Test {

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
has Numeric:D $.vikna-timeout where * > 0 = 60;

method setup-from-plan(%plan) {
    callsame;
    $!vikna-timeout = $_ with %plan<vikna-timeout>:delete;
}

my class SeqTask {
    has Mu $.type;
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
    has Vikna::Widget:D $.widget is required;
    has $.origin is built(:bind) = Nil;
    has $.dispatcher is built(:bind) = $!widget;
    has Str $.message is mooish(:lazy);
    has Str $.comment;
    # Syncer objects as returned by evs-syncer
    has $.skip-until is mooish(:filter<filter-syncer>);
#    has $.wait-until is mooish(:filter<filter-syncer>);
    # Invoke desktop quit upon test failure
    has Bool:D $.quit-on-flunk = False;

    method filter-syncer(Any:D $value) {
        $value ~~ Str ?? EXPORT::DEFAULT::evs-syncer($value) !! $value
    }

    submethod TWEAK(|) {
        $!tout-promise = Promise.anyof($!completed, Promise.in($!timeout).then: {
            # Only fail if task haven't completed.
            $!complete-lock.protect: {
                if $!completed.status ~~ Planned {
                    #                        note "TIMED OUT '$!message'";
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

#    method maybe-wait {
#        with $!wait-until {
#            CATCH { default {
#                note "Waiting for syncer '", $!wait-until.name, "' failed: ", ~$_, ~$_.bt;
#                exit 1;
#            } }
#            try await Promise.anyof(.promise, $!completed);
#            if .failed {
#                self!set-status: False;
#            }
#        }
#        self
#    }

    # The method returns True if event type is matching and accept callback confirms acceptance.
    # Returned False means that event has been skipped.
    method match(Event:D $ev) {
        fail X::TaskCompleted unless $!completed.status ~~ Planned;
        with $!skip-until {
            unless .ready {
                self!set-status: False if .failed;
                return False;
            }
        }
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
        #            note "TASK '$!message' passed: $passed status: ", $!completed.status;
        if $!completed.status ~~ Planned {
            $!completed-vow.keep($passed);
            .($passed, self) with &!on-status;
            #                note "once again: passed? ", $passed;
            unless $passed {
                #                    note "QUIT DESKTOP($!message) $!quit-on-flunk";
                $!widget.app.desktop.quit if $!quit-on-flunk;
            }
        }
    }

    method passed {
        .status ~~ Planned ?? Nil !! .result with $!completed
    }
}

my role EvReporter {
    has atomicint $!trace-events = 0;
    has Supplier:D $.ev-postproc .= new;
#    has Supplier:D $.ev-preproc .= new;
    submethod TWEAK(|) {
        self.events.Supply.tap: done => { $!ev-postproc.done };
    }
    proto method event(Event:D) {*}
    multi method event(Event:D $ev) {
        note "-- [{ self.name }] $ev" if $!trace-events;
#        $!ev-preproc.emit: $ev;
        my $rc = callsame;
        $!ev-postproc.emit: [$ev, $rc ~~ Slip ?? $rc.List !! $rc];
        $rc
    }
    method trace-events(Bool :$off = False) {
        if $off {
            --⚛$!trace-events
        }
        else {
            ++⚛$!trace-events
        }
    }
}

method is-event-sequence(Vikna::Widget:D $widget,
                         Iterable:D $task-list,
                         Str:D $message,
                         :$timeout = $!vikna-timeout,
                         :$async = False,
                         :$trace-events = False,
                         :%defaults) is test-tool {
    unless $widget ~~ EvReporter {
        $widget does EvReporter;
    }

    # With $test-ready we make sure that subtest code has started and won't miss any upcoming event.
    my $test-ready = Promise.new;
    my $test-promise = self.subtest: $message, :$async, :instant, :hidden, -> \suite {
        $widget.trace-events if $trace-events;
        LEAVE { $widget.trace-events: :off if $trace-events }

        # If user on-match callback returns an iterator, push the previous one on the stack.
        my @iter-stack;

        # Current iterator we use for pulling tasks.
        my $cur-iter = $task-list.iterator;

        # SeqTask instance we're currently working with.
        my $cur-task;

        my $stop-react = Promise.new;

        # Internally stacking of iterators is supported. I.e. it is possible in the middle of a task queue processing
        # to push a new iterator on the stack, run through its tasks, and when over pop the previous one and proceed from
        # where it was put on hold. But for now there is no support for this in the user interfaces and there is no
        # certainty over benefits of this feature.
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

            #                note "TASK: ", %defaults;
            $cur-task = SeqTask.new: :$widget, |%defaults, |$task, :$timeout, :suite(test-suite);

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
#            whenever $widget.ev-preproc -> $ev {
#                unless $cur-task.pre-match($ev) {
#                    $stop-react.keep("event-preproc");
#                }
#            }
            whenever $widget.ev-postproc -> [$ev, $rc] {
                # TODO Add support for $rc processing too.
                my $*TEST-SUITE = suite;
                if $cur-task.match($ev) {
                    $stop-react.keep("event-postproc") unless $cur-task.passed && next-task;
                }
            }
            whenever $stop-react {
                done;
            }
            $test-ready.keep(True);
        }
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
            self.diag: "WARNING: unknown key in profile: $key\n", "         No such attribute on Vikna::Canvas::Cell";
        }
    }
    my $flunked = False;
    my @diag;
    for $rect.x .. $rect.right -> $x {
        for $rect.y .. $rect.bottom -> $y {
            my $cell = $canvas.pick($x, $y);
            for %c.keys -> $key {
                next unless $cell.^can($key);
                unless $cell."$key"() eqv %c{$key} {
                    @diag.append: self.expected-got(%c{$key}.raku, $cell."$key"().raku, :exp-sfx("'$key'")), "\n";
                    $flunked = True;
                }
            }
            if $flunked {
                self.flunk: $message;
                self.diag: "At pos $x, $y attribute{ +@diag > 1 ?? 's' !! '' } doesn't match\n", @diag;
                return False;
            }
        }
    }
    self.pass: $message;
}};

package EXPORT {
    package DEFAULT {
        # Syncing promises for parallel is-event-sequence
        my class EvsSyncer {
            has Str:D $.name is required;
            has Promise:D $.promise handles<status> .= new;
            has $!vow = $!promise.vow;
            has Lock:D $!lock .= new;
            method hand-over(Mu $value = True) {
                $!lock.protect: {
                    $!vow.keep($value) if $!promise.status ~~ Planned;
                }
            }
            method abort(Mu $value = False) {
                $!lock.protect: {
                    $!vow.break($value) if $!promise.status ~~ Planned;
                }
            }
            method signal(Bool:D $passed, Mu :$value = $passed) {
                $passed ?? self.hand-over($value) !! self.abort($value);
            }
            method ready {
                $!lock.protect: {
                    $!promise.status ~~ Kept
                }
            }
            method failed {
                $!lock.protect: {
                    $!promise.status ~~ Broken
                }
            }
        }
        my %syncers;
        my $slock = Lock.new;
        our sub evs-syncer(Str:D $name) {
            $slock.protect: {
                unless %syncers{$name} {
                    my $syncer = EvsSyncer.new: :$name;
                    %syncers{$name} = $syncer;
                }
                %syncers{$name}
            }
        }
        our sub evs-task(Mu \evType, Str $message?, *%profile) {
            %(
                type => evType, (:$message with $message), |%profile
            )
        }
    }
}