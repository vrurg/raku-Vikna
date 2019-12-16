use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Desktop is Vikna::Widget is export;

use Vikna::Events;

method on-screen-resize {
    my $old-w = $.w;
    my $old-h = $.h;
    $.app.screen.setup(:reset);
    $.app.debug: "Desktop resized to ", $.w, " x ", $.h;
    # Do it in two events as screen resize might be handy for a child widget. But otherwise it's a normal resize event.
    self.dispatch: Event::ScreenResize, :$old-w, :$old-h, :$.w, :$.h;
    self.dispatch: Event::Resize, :$old-w, :$old-h, :$.w, :$.h;
}

multi method invalidate() {
    $.app.debug: "Full desktop invalidate";
    self.invalidate: $.geom.clone
}

method redraw {
    callsame;
    self.compose;
    $.app.screen.print: 0, 0, $.canvas;
}

multi method event(Event::RedrawRequest:D) {
    # Queue up resizes so we miss no one.
    self.redraw;
}

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }
