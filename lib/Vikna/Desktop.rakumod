use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Desktop is Vikna::Widget is export;

use Vikna::Events;
use Vikna::Rect;
use Vikna::Utils;

has Semaphore:D $!redraws .= new(1);
has Event $!redraw-on-hold;

submethod TWEAK {
    self.redraw;
}

method on-screen-resize {
    my $old-w = $.w;
    my $old-h = $.h;
    $.app.screen.setup(:reset);
    $.app.debug: "Desktop resized to ", $.w, " x ", $.h;
    # Do it in two events as screen resize might be handy for a child widget. But otherwise it's a normal resize event.
    self.dispatch: Event::ScreenResize, :$old-w, :$old-h, :$.w, :$.h;
    self.dispatch: Event::Resize, :$old-w, :$old-h, :$.w, :$.h;
}

### Command handlers ###

method cmd-redraw(Event::Cmd::Redraw:D $ev) {
    callsame;
    $.debug: "-> screen!";
    $.app.screen.print: 0, 0, $.canvas;
}

### Utility methods ###

multi method invalidate(Vikna::Rect:D $rect) {
    $.debug: "DESKTOP INVALIDATION: $rect";
    $.add-inv-rect: $rect;
}

method redraw {
    $.debug: "DESKTOP REDRAW";
    $.draw-protect: {
        $.debug: " -> redrawing, invalidations: ", +@.invalidations;
        if @.invalidations {
            $.debug: "DESKTOP self invalidate";
            $.invalidate if $.auto-clear;
            my @invalidations = @.invalidations;
            $.debug: "DESKTOP self clear invalidations";
            $.clear-invalidations;
            $.debug: "DISPATCHING DESKTOP REDRAW COMMAND";
            self.dispatch: Event::Cmd::Redraw, :@invalidations;
        }
    }
}

# Filters are protected from concurrency by EventHandling
multi method event-filter(Event::Cmd::Redraw:D $ev) {
    $.debug: "DESKTOP EV FILTER: ", $ev.^name;
    if $!redraws.try_acquire {
        # There is no current redraws, we just proceed further but first make sure we release the resource when done.
        $ev.redrawn.then: {
            $.debug: "RELEASING REDRAW SEMAPHORE";
            $!redraws.release;
            cas $!redraw-on-hold, {
                # If there is a redraw event pending then release it into the wild.
                $.debug: "RELEASE HELD EVENT: ", .WHICH, " with invs: ", .invalidations.elems;
                self.send-event: $_ if $_;
                Nil
            };
        };
        [$ev]
    }
    else {
        # There is another redraw active.
        $.debug: "PUT ", $ev.WHICH, " on hold";
        cas $!redraw-on-hold, {
            # If set already we don't change it, just add new invalidations.
            if $_ {
                .invalidations.append: $ev.invalidations;
                # Any attempt to use canvas from this redraw command will result in explosion.
                # $ev.redrawn.break(self.fail: X::Event::LostRedraw, ev => $_);
                $ev.redrawn.keep(True);
                $_
            }
            else {
                $ev
            }
        }
        # This event won't go any further...
        []
    }
}

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }
