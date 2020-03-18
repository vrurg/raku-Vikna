use v6.e.PREVIEW;

unit class Vikna::Desktop;

use Vikna::Widget;
use Vikna::PointerTarget;
use Vikna::Focusable;
use Vikna::Events;
use Vikna::EventEmitter;
use Vikna::Rect;
use Vikna::Utils;
use Vikna::Dev::Kbd;

also does Vikna::PointerTarget;
also does Vikna::Focusable;
also is Vikna::Widget;

has Bool:D $!print-needed = False;
has Vikna::Canvas $!on-screen-canvas;

submethod profile-default {
    attr => {
        :bg<default>,
        :fg<default>,
        :pattern<.>,
    },
    focus-topmost => True,
}

### Event handlers ###
my @bg-chars = <+ * .>;
multi method event(::?CLASS:D: Event::Screen::Geom:D $ev) {
    my $chr = @bg-chars.shift;
    $.cmd-setbgpattern: $chr;
    @bg-chars.push: $chr;
    $.cmd-setgeom: $ev.to, :no-draw;
    $.cmd-redraw;
}

multi method event(::?CLASS:D: Event::Screen::Ready:D $ev) {
    $.flatten-unblock;
    if $!print-needed {
        $.trace: "SCREEN READY, trying printing again";
        # This would result in a call to the print method.
        $.flatten-canvas;
    }
}

has $.presses = 0;
multi method dispatch(::?CLASS:D: Event::Kbd::Control:D $ev, |c) {
    if K_Control ∈ $ev.modifiers && $ev.key eq 'C' {
        $.quit;
        # $.dispatch: Event::Quit;
        # # Quick reaction expected, thus bypass the normal event handling.
        # $.cmd-quit;
        if ++$!presses > 1 {
            $.app.panic( X::AdHoc.new: :payload("oops..."), :object(self) );
            exit 1;
        }
    }
}

### Command handlers ###

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
    $!on-screen-canvas = $_ with $canvas;
    if $.app.screen.print(0, 0, $!on-screen-canvas) {
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
    $.trace: "Let the event queue start";
    callsame;
    $.trace: "Adding event sources";
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
