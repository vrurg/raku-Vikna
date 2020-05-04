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
    },
    focus-topmost => True,
}

submethod TWEAK {
    self.app.screen.hide-cursor;
}

### Event handlers ###
my @bg-chars = <+ * .>;
multi method event(::?CLASS:D: Event::Screen::Geom:D $ev) {
    my $chr = @bg-chars.shift;
    self.cmd-setbgpattern: $chr;
    @bg-chars.push: $chr;
    self.cmd-setgeom: $ev.to, :no-draw;
    $.cmd-redraw;
}

multi method event(::?CLASS:D: Event::Screen::Ready:D $ev --> Nil) {
    $.flatten-unblock;
    if $!print-needed {
        self.trace: "SCREEN READY, trying printing again";
        # This would result in a call to the print method.
        $.flatten-canvas;
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

method print(::?CLASS:D: Vikna::Canvas:D $canvas?) {
    self.trace: "DESKTOP REDRAW -> screen";
    $!on-screen-canvas = $_ with $canvas;
    if $.app.screen.print(0, 0, $!on-screen-canvas) {
        $!print-needed = False;
        $.flatten-block;
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

method flatten-canvas {
    # The print-needed flag will be reset if flattening is unblocked and screen print started successfully. Otherwise it
    # will signal that when screen is ready again we must print again immediately.
    $!print-needed = True;
    nextsame;
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
