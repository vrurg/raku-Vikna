use v6.e.PREVIEW;
# Screen driver
use Vikna::Object;
use Vikna::EventEmitter;
use Vikna::EventHandling;
use Vikna::CommandHandling;

unit role Vikna::Screen;
also is Vikna::Object;
also does Vikna::EventHandling;
also does Vikna::EventEmitter;
also does Vikna::CommandHandling;

use Vikna::Point;
use Vikna::Rect;
use AttrX::Mooish;
use Vikna::Events;
use Vikna::Color;
use Vikna::Canvas;
use Vikna::Color::RGB;

has Vikna::Rect $.geom is mooish(:lazy, :clearer, :predicate);
has Bool $.is-unicode is mooish(:lazy, :clearer);
has Int $.color-depth is mooish(:lazy);
has Promise:D $.availability_promise is rw .= kept; # Initially we're ready for output
has Promise:D $.shutting-down .= new;
has Lock:D $.print-lock .= new;

method build-is-unicode { ... }
method build-color-depth { ... }
method build-geom       { ... }

method screen-print(Int:D, Int:D, |) {...}
method hide-cursor {...}
method show-cursor {...}

proto method move-cursor(|) {*}
multi method move-cursor(Vikna::Point:D $pos) { self.move-cursor($pos.x, $pos.y) }
multi method move-cursor(UInt:D $x, UInt:D $y) {...}

method init { ... }
method shutdown {
    $!shutting-down.keep(True);
}

# Color mapping routines. Map into what current screen understands.
# proto method color(|) {*}
# multi method color(Str:D $name)                     { ... }
# multi method color(UInt:D $r, UInt:D $g, UInt:D $b, UInt:D $a?) { ... }
# multi method color(*%chan)                          { ... }
# multi method color(Vikna::Color:D)                  { ... }
# multi method color(Any:U)                           { Vikna::Color::RGB }

method cmd-screenprint(::?CLASS:D: Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, *%c ) {
    $.screen-print($x, $y, $viewport, |%c);
    $.post-event: Event::Screen::Ready;
    $!availability_promise.keep(True);
}

proto method print(::?CLASS:D: |) {*}
multi method print(Vikna::Point:D $pos, Vikna::Canvas:D $viewport, *%c ) { self.print: $pos.x, $pos.y, $viewport, |%c }
multi method print(Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, *%c ) {
    $!print-lock.protect: {
        if $!availability_promise.status ~~ Planned {
            False
        }
        else {
            # Available
            $!availability_promise = Promise.new;
            $.send-command: Event::Cmd::ScreenPrint, $x, $y, $viewport, |%c;
            True
        }
    }
}

method screen-resize {
    my $from = $!geom;
    $.clear-geom;
    $.post-event: Event::Screen::Geom, :$from, to => $!geom;
}

method panic($cause) {
    self.Vikna::EventEmitter::panic($cause);
    nextsame;
}
