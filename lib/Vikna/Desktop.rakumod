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

has $!cursor-show-requests = 0;

submethod profile-default {
    attr => {
        :bg<default>,
        :fg<default>,
        :pattern<.>,
        :style(VSNone),
    },
    focus-topmost => True,
}

submethod TWEAK {
    self.app.screen.hide-cursor;
}

### Event handlers ###
multi method event(::?CLASS:D: Event::Screen::Geom:D $ev) {
    self.cmd-setgeom: .x, .y, .w, .h, :no-draw with $ev.to;
    self.cmd-redraw;
}

multi method event(::?CLASS:D: Event::Screen::Ready:D $ev --> Nil) {
    if $!print-needed {
        self.trace: "SCREEN READY, trying printing again";
        self.print;
    }
}

has $.presses = 0;
multi method dispatch(::?CLASS:D: Event::Kbd::Control:D $ev, |c) {
    if K_Control ∈ $ev.modifiers && $ev.key eq 'C' {
        $.quit;
        # self.dispatch: Event::Quit;
        # # Quick reaction expected, thus bypass the normal event handling.
        # $.cmd-quit;
        if ++$!presses > 1 {
            $.app.panic( X::AdHoc.new: :payload("oops..."), :object(self) );
            exit 1;
        }
    }
    else {
        nextsame
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
    self.dispatch: Event::Quit;
    self.send-command: Event::Cmd::Quit;
}

### Utility methods ###

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }

has Lock:D $!print-lock .= new;
method print(::?CLASS:D: Vikna::Canvas $canvas?) {
    $!print-lock.protect: {
        # If re-print requested but no $!on-screen-canvas defined it likely means a concurrent print invoked by
        # flatten-canvas has succeed.
        return unless $canvas || $!on-screen-canvas;
        self.trace: "DESKTOP REDRAW -> screen";
        if $!on-screen-canvas && $canvas {
            $canvas.invalidate: $_ for $!on-screen-canvas.invalidations;
        }
        $!on-screen-canvas = $_ with $canvas;
        if $.app.screen.print(0, 0, $!on-screen-canvas) {
            self.dispatch: Event::Updated, geom => $!on-screen-canvas.geom;
            $!on-screen-canvas = Nil;
            $!print-needed = False;
        }
        else {
            $!print-needed = True;
        }
    }
}

method show-cursor {
    if ++$!cursor-show-requests == 1 {
        $.app.screen.show-cursor;
    }
}

method hide-cursor {
    given --$!cursor-show-requests {
        when 0 {
            $.app.screen.hide-cursor;
        }
        when * < 0 {
            self.throw: X::OverUnblock, what => 'cursor hide', count => $_
        }
    }
}

method start-event-handling {
    my &super := nextcallee;
    self.flow: {
        #    self.trace: "Let the event queue start";
        self.&super();
        #    self.trace: "Adding event sources";
        self.add-event-source: $_ for $.app.inputs;
    }, :name('Start Desktop Event Loop'), :sync
}

method panic-shutdown($cause) {
    self.trace: "DESKTOP PANIC SHUTDOWN: " ~ $cause;
    $.stop-event-handling;
    $.app.screen.show-cursor;
    try $.app.screen.shutdown;
    $.dismissed.keep(False) if $.dismissed.status ~~ Planned;
    CATCH {
        default {
            note "DESKTOP PANIC PANICED: ", .message, ~ .backtrace;
            .resume;
        }
    }
}

method shutdown {
    $.app.screen.show-cursor;
    callsame;
}
