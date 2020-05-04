use v6.e.PREVIEW;

use Test::Async::Decl;

unit test-bundle Vikna::Test;

use Vikna::Canvas;
use Vikna::Rect;
use Vikna::Widget;
use Vikna::Events;
use AttrX::Mooish;
use Test::Async::Hub;
use Test::Async::Decl;
use Test::Async::Utils;

# Default timeout for some tests
has Numeric:D $.vikna-timeout where * > 0 = 5;

method setup-from-plan( %plan ) {
    callsame;
    $!vikna-timeout = $_ with %plan<vikna-timeout>:delete;
}

my role EvReporter {
    has Supplier:D $.ev-postproc .= new;
    submethod TWEAK( | ) {
        self.events.Supply.tap: done => { $!ev-postproc.done };
    }
    proto method event( Event:D ) {*}
    multi method event( Event:D $ev ) {
        my $rc = callsame;
        $rc .= List if $rc ~~ Slip;
        $!ev-postproc.emit: [$ev, $rc];
        $rc
    }
}
my class SeqTask {
    has $.type is built( :bind );
    has Promise:D $.completed .= new;
    has Lock:D $!complete-lock .= new;
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
    has $.origin is built( :bind ) = Nil;
    has $.dispatcher is built( :bind ) = Nil;
    has Str $.message is mooish( :lazy );
    has Str $.comment;

    submethod TWEAK( | ) {
        $!tout-promise = Promise.anyof(
                $!completed,
                Promise.in($!timeout).then: {
#                    note "TASK TIME OUT: ", $!message;
                    self.fail(:comment( "Timed out after $!timeout sec" ));
                }
            )
    }

    method build-message {
        "event " ~ $!type.^name
            ~ ( $!origin !=== Nil ?? " orig=" ~ $!origin !! "" )
            ~ ( $!dispatcher !=== Nil ?? " disp=" ~ $!dispatcher !! "" )
    }

    method !match-widget( Mu \a, Mu \b ) {
        return True if b === Nil;
        b.defined ?? ( a === b ) !! ( a ~~ b )
    }

    method !checker-ok( $ev ) {
        &!checker.defined ?? &!checker( $ev ) !! True
    }

    method !event-accepted( $ev ) {
        &!accept ?? &!accept( $ev ) !! True
    }

    method comment-widget-match( \got, \expected, $kind ) {
        $!comment = "Event $kind doesn't match.\n"
            ~ "  expected: " ~ expected.WHICH
            ~ "       got: " ~ got.WHICH
    }

    # The method returns True if event type is matching and accept callback confirms acceptance.
    # Returned False means that event has been skipped.
    method match( Event:D $ev ) {
        if $ev ~~ $!type && self!event-accepted($ev) {
            # Event has been accepted for processing. Doesn't mean yet it passes the task.
            my $passed = False;
            if !self!match-widget($ev.origin, $!origin) {
                self.comment-widget-match($ev.origin, $!origin, 'origin')
            }
            elsif !self!match-widget($ev.dispatcher, $!dispatcher) {
                self.comment-widget-match($ev.dispatcher, $!dispatcher, 'dispatcher')
            }
            elsif !self!checker-ok($ev) {
                $!comment = "User supplied checker doesn't pass for event " ~ $ev;
            }
            else {
                $passed = True;
            }
            self!set-status($passed);
            True
        }
        else {
            False
        }
    }

    method !set-status( $passed, :$comment? ) {
        $!complete-lock.protect: {
            # note "TASK '$!message' status: ", $!completed.status;
            if $!completed.status ~~ Planned {
                $!comment = $_ with $comment;
                $passed
                    ?? $!completed.keep(self)
                    !! $!completed.break(self);
                .( $passed, self ) with &!on-status;
            }
        }
    }

    method fail( *%c ) {
        self!set-status(False, |%c)
    }
    method success {
        self!set-status(True)
    }

    method passed {
        $!completed.status ~~ Kept
    }
}

method is-event-sequence(
    Vikna::Widget:D $widget,
    Iterable:D $task-list,
    Str:D $message,
    :$timeout = $!vikna-timeout,
    :$async = False,
                         ) is test-tool
{
    self.subtest: $message, :$async, :instant, :hidden, -> \suite {
        # If user on-match callback returns and iterator, push the previous one on the stack.
        my @iter-stack;

        # Current iterator we use for pulling tasks.
        my $cur-iter = $task-list.iterator;

        # SeqTask instance we're currently working with.
        my $cur-task;

        my $stop-react = Promise.new;

        my sub push-iterator( $new-iter ) {
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

#            note "TASK: ", $task.WHICH;

            $cur-task = SeqTask.new: :dispatcher($widget), |$task, :$timeout, :suite(test-suite);

#            note "Task timeout: ", $cur-task.timeout;

            $cur-task.completed.then: -> $p {
                # note "TASK '{$cur-task.message}' promise.then: ", $p.status;
                CATCH { default {
                    note $_, ~$_.backtrace;
                    exit 255;
                } }
                my $passed = $p.status ~~ Kept;
#                note " -- PASSED: $passed";
                suite.ok: $passed, $cur-task.message;
                suite.diag: $cur-task.comment if !$passed && $cur-task.comment;
                $stop-react.keep("cur-task") if $stop-react.status ~~ Planned && !$passed;
                # For a sequence to succeed all of it tasks must pass.
            }
#            note "next-task done";
            $cur-task
        }

        unless $widget ~~ EvReporter {
            $widget does EvReporter
        }

        next-task;

        $widget.dismissed.then: {
            $cur-task.fail(:comment( 'Premature event queue shut down' ));
            $stop-react.keep("ev-queue done") if $stop-react.status ~~ Planned;
        };

        note "TEST SUITE OUT: ", test-suite.WHICH;
        react {
            whenever $widget.ev-postproc -> [$ev, $rc] {
                my $*TEST-SUITE = suite;
#                note "-EV- ", $ev.WHICH, ": ", ~$ev;
                if $cur-task.match($ev) {
                    my $cb-ret = .( $ev, $cur-task ) with $cur-task.on-match;
                    if $cur-task.passed {
                        if $cb-ret ~~ Iterable {
                            push-iterator($cb-ret.iterator);
                        }
                        done unless next-task;
                    }
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
}

proto method is-rect-filled( | ) is test-tool {*}
multi method is-rect-filled( Vikna::Canvas:D $canvas, Vikna::Rect:D $rect, Str:D $message, *%c ) {
    my $matches = True;
    for $rect.x .. $rect.right -> $x {
        for $rect.y .. $rect.bottom -> $y {
            my $cell = $canvas.pick($x, $y);
            for %c.keys -> $attr {
                unless $cell."$attr"() eqv %c{$attr} {
                    self.flunk: $message;
                    return;
                }
            }
        }
    }
    self.pass: $message;
}
