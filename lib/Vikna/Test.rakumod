use v6.e.PREVIEW;
use Test::Async::Base;
use Test::Async::Decl;

unit test-bundle Vikna::Test;

use Vikna::Canvas;
use Vikna::Rect;
use Vikna::Widget;
use Vikna::Events;
# use Vikna::Test::EventSequencer;

# Default timeout for some tests
has Numeric:D $.vikna-timeout where * > 0 = 5;

method setup-from-plan(%plan) {
    callsame;
    $!vikna-timeout = $_ with %plan<vikna-timeout>:delete;
}

proto method sequence-events(Vikna::Widget:D, Iterable:D, Str:D, |) is test-tool {*}
multi method sequence-events(Vikna::Widget:D $widget, Iterable:D $tasks, Str:D $message, :$timeout = $!vikna-timeout) {
    my sub sequencer {
        my role EvReporter {
            has Supplier:D $.ev-postproc .= new;
            proto method event(Event:D) {*}
            multi method event(Event:D $ev) {
                my $rc = callsame;
                $!ev-postproc.emit: [$ev, $rc];
                $rc
            }
        }
        unless $widget ~~ EvReporter {
            $widget does EvReporter
        }
        given self {
            .plan: 1;
            .pass: "sequencing";
        }
    }
    self.subtest: $message, &sequencer, :instant;
}

proto method is-rect-filled(|) is test-tool {*}
multi method is-rect-filled(Vikna::Canvas:D $canvas, Vikna::Rect:D $rect, Str:D $message, *%c) is export {
    my $matches = True;
    for $rect.x..$rect.right -> $x {
        for $rect.y..$rect.bottom -> $y {
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
