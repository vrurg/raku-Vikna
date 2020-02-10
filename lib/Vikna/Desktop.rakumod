use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Desktop is Vikna::Widget is export;

use Vikna::Events;
use Vikna::EventEmitter;
use Vikna::Rect;
use Vikna::Utils;
use Vikna::Dev::Kbd;

has Bool:D $!print-needed = False;
has Vikna::Canvas $!pcanvas;

### Event handlers ###
multi method event(Event::Screen::Geom:D $ev) {
    self.set-geom: $ev.to;
}

multi method event(Event::Screen::Ready:D $ev) {
    if $!print-needed {
        $.trace: "SCREEN READY, trying printing again";
        $!print-needed = False;
        $.print: $!pcanvas;
    }
}

has $.presses = 0;
multi method event(Event::Kbd::Control:D $ev) {
    if K_Control ∈ $ev.modifiers && $ev.key eq 'C' {
        $.close;
        if ++$!presses > 2 {
            die "oops...";
            $.shutdown;
            exit 1;
        }
    }
}

### Command handlers ###
# method cmd-childcanvas($child, Vikna::Rect:D $canvas-geom, Vikna::Canvas:D $canvas, @invalidations) {
#     callsame;
#     $.canvas.imprint(0,0,$canvas);
#     0
# }

### Utility methods ###

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }

method print(::?CLASS:D: Vikna::Canvas:D $canvas?) {
    $.trace: "DESKTOP REDRAW -> screen";
    $!pcanvas = $_ with $canvas;
    unless $.app.screen.print(0, 0, $!pcanvas) {
        $.trace: "POSTPONE, screen not ready.";
        $!print-needed = True;
    }
}

method start-event-handling {
    callsame;
    $.add-event-source: $_ for $.app.inputs;
}

method panic-shutdown($cause) {
    $.trace: "DESKTOP PANIC SHUTDOWN: " ~ $cause;
    $.stop-event-handling;
    $.app.screen.shutdown;
    $.dismissed.keep(False) if $.dismissed.status ~~ Planned;
    CATCH {
        default {
            note "DESKTOP PANIC PANICED: ", .message, ~ .backtrace;
            .resume;
        }
    }
}

method shutdown {
    callsame;
    $.app.screen.shutdown;
}
