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
my @bg-chars = <+ * .>;
multi method event(Event::Screen::Geom:D $ev) {
    my $chr = @bg-chars.shift;
    $.cmd-setbgpattern: $chr;
    @bg-chars.push: $chr;
    $.cmd-setgeom: $ev.to, :no-draw;
    $.cmd-redraw;
}

multi method event(Event::Screen::Ready:D $ev) {
    $.flatten-unblock;
    if $!print-needed {
        $.trace: "SCREEN READY, trying printing again";
        # This would result in a call to the print method.
        $.flatten-canvas;
    }
}

has $.presses = 0;
multi method event(Event::Kbd::Control:D $ev) {
    if K_Control ∈ $ev.modifiers && $ev.key eq 'C' {
        $.dispatch: Event::Quit;
        # Quick reaction expected, thus bypass the normal event handling.
        $.cmd-quit;
        if ++$!presses > 1 {
            $.app.panic( X::AdHoc.new: :payload("oops..."), :object(self) );
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

method cmd-quit {
    $.cmd-close;
}

### Command senders ###

method quit {
    # Exceptional case: pre-send notification event prior to command execution. Event::Quit has immediate priority thus
    # will give child widgets time to take care of themselves.
    $.dispatch: Event::Quit;
    $.send-command: Event::Cmd::Quit;
}

### Utility methods ###

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }

method print(::?CLASS:D: Vikna::Canvas:D $canvas?) {
    $.trace: "DESKTOP REDRAW -> screen";
    $!pcanvas = $_ with $canvas;
    if $.app.screen.print(0, 0, $!pcanvas) {
        $!print-needed = False;
        $.flatten-block;
    }
}

method flatten-canvas {
    # The print-needed flag will be reset if flattening is unblocked and screen print started successfully. Otherwise it
    # will signal that when screen is ready again we must print again immediately.
    $!print-needed = True;
    nextsame;
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
