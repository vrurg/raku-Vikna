use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Desktop is Vikna::Widget is export;

use Vikna::Events;
use Vikna::EventEmitter;
use Vikna::Rect;
use Vikna::Utils;
use Vikna::Dev::Kbd;

has Bool:D $!print-needed = False;

### Event handlers ###
multi method event(Event::Screen::Geom:D $ev) {
    self.set-geom: $ev.to;
}

multi method event(Event::Screen::Ready:D $ev) {
    if $!print-needed {
        $.app.screen.print: 0, 0, $.canvas;
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
has atomicint $!redraws = 0;
method cmd-redraw(|) {
    callsame;
    $.trace: "DESKTOP REDRAW -> screen";
    # $.canvas.invalidate(0,0,20,1);
    # $.canvas.imprint: 0,0, "r:" ~ ++⚛$!redraws;
    $.app.screen.print: 0, 0, $.canvas;
}

method cmd-childcanvas($child, Vikna::Rect:D $canvas-geom, Vikna::Canvas:D $canvas, @invalidations) {
    callsame;
    $!print-needed = True;
#     $.trace: "DESKTOP CHILD CANVAS -> screen";
#     if $child.name eq 'Moveable' {
#         $.app.screen.print: 0, $.app.screen.geom.h - $canvas.h, $canvas;
#     }
#     # $.redraw;
#     # $.canvas.invalidate(0,0,20,1);
#     # $.canvas.imprint: 0,0, "r:" ~ ++⚛$!redraws;
#     # $.app.screen.print: 0, 0, $.canvas;
}

### Utility methods ###

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }

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
