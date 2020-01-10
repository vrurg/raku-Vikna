use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Desktop is Vikna::Widget is export;

use Vikna::Events;
use Vikna::Rect;
use Vikna::Utils;

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

method cmd-redraw(|) {
    callsame;
    $.debug: "-> screen!";
    $.app.screen.print: 0, 0, $.canvas;
}

### Utility methods ###

# method redraw {
#     $.debug: "DESKTOP REDRAW";
#     $.draw-protect: {
#         $.debug: " -> redrawing, invalidations: ", +@.invalidations;
#         if @.invalidations {
#             $.debug: "DESKTOP self invalidate";
#             $.invalidate if $.auto-clear;
#             my @invalidations = @.invalidations;
#             $.debug: "DESKTOP self clear invalidations";
#             $.clear-invalidations;
#             $.debug: "DISPATCHING DESKTOP REDRAW COMMAND";
#             self.send-command: Event::Cmd::Redraw, @invalidations;
#         }
#     }
# }

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }
