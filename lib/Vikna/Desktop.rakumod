use v6;
use Vikna::Widget;
unit class Vikna::Desktop is Vikna::Widget is export;

use Vikna::Events;

has Lock:D $!draw-lock .= new;

submethod TWEAK(|) {
    signal(SIGWINCH).tap: {
        self.on-screen-resize
    }
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

method redraw {
    $.app.debug: "Desktop redraw ", $.w, ' x ', $.h;
    $!draw-lock.lock;
    $.app.debug: "Desktop redraw callsame ", $.w, ' x ', $.h;
    callsame;
    $.app.debug: "Desktop redraw composite ", $.w, ' x ', $.h;
    self.composite;
    $.app.debug: "Desktop redraw complete ", $.w, ' x ', $.h;
    LEAVE $!draw-lock.unlock;
}

multi method event(Event::Resize:D) {
    # Queue up resizes so we miss no one.
    self.redraw;
}

# Desktop doesn't allow resize unless through screen resize
method resize(|) { }
