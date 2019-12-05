use v6;
use Terminal::Print::Widget;
use Term::UI::Parent;
use Term::UI::Child;
use Term::UI::Belongable;
use Term::UI::EventHandling;
unit class Term::UI::Widget is Terminal::Print::Widget is export;
also does Term::UI::Parent[::?CLASS];
also does Term::UI::Child;
also does Term::UI::Belongable[::?CLASS];
also does Term::UI::EventHandling;

use Term::UI::Events;
use Term::UI::X;

has $.app is required;
has $.bg-pattern;
has $.bg-color;
has Bool:D $.auto-clear = False;
has Terminal::Print::Grid $!draw-grid;
has Lock:D $!draw-lock .= new;

submethod TWEAK(|c) {
    .add-child(self) with $!parent;
    self.ev.subscribe: -> $ev { self.event: $ev }
}

method create-child(Term::UI::Widget:U $wtype, |c) {
    $wtype.new: :$!app, :parent(self), :owner(self), |c;
}

proto method event(Event:D $ev) {
    {*}

    unless $ev.clear {
        .event($ev) for @.children;
    }
}

multi method event(Event::Resize:D $ev) {
    self.redraw;
}

# Sink any unhandled event. Clear if we originated it.
multi method event(Event:D $ev) {
    $ev.clear if $ev.origin === self
}

method debug(*@args) {
    $.app.debug: "({self.WHICH}) ", |@args;
}

method clear {
    .clear for @.children;
    $.grid.clear;
}

method begin-draw {
    $!draw-lock.protect: {
        $!draw-grid = $!auto-clear ?? $.grid.new-from-self !! $.grid.clone;
        $.debug: "begin-draw grid: ", $!draw-grid.WHICH, " ", $!draw-grid.w, " x ", $!draw-grid.h;
        $!draw-grid
    }
}

method end-draw( :$grid! ) {
    $!draw-lock.protect: {
        $.debug: "end-draw   grid: ", $.grid.WHICH;
        # Due to possible concurrent redraws, widget might have changed its size in another thread while drawing in this
        # thread. It means we must not replace the backing grid if ours is outdated.
        if $grid === $!draw-grid
            && $grid.w == $.w
            && $grid.h == $.h
        {
            $.debug: "end-draw replacing grid ", $!draw-grid.w, " x ", $!draw-grid.h;
            self.replace-grid: $!draw-grid;
            $!draw-grid = Nil;
        }
    }
}

method redraw {
    my $grid = self.begin-draw;
    my $abort-draw = False;
    for @.children {
        # Stop if another thread started drawing.
        last if $abort-draw = !($grid === $!draw-grid);
        .redraw;
    }
    self.draw-background( :$grid );
    unless $abort-draw {
        self.?draw( :$grid );
    }
    self.debug: "Aborted draw? ", $abort-draw;
    self.end-draw( :$grid );
}

method draw-background( :$grid ) {
    if $!bg-pattern {
        my $back-row = ( $!bg-pattern x ($.w.Num / $!bg-pattern.chars).ceiling ).substr: ^$.w;
        for ^$.h -> $row {
            $grid.set-span( 0, $row, $back-row, $!bg-color );
        }
    }
}

method composite {
    $!draw-lock.lock;
    .composite(to => $.grid) for @.children;
    callsame;
    LEAVE $!draw-lock.unlock;
}

method resize(Int:D :$w where * > 0 = $.w, Int:D :$h where * > 0 = $.h) {
    $.debug: "? resizing to $w x $h";
    my $old-w = $.w;
    my $old-h = $.h;
    self.replace-grid: $.grid.clone(:$w, :$h);
    $.debug: "resized grid: ", $.grid.w, " x ", $.grid.h;
    self.dispatch(Event::Resize, :$old-w, :$old-h, :$w, :$h) if $old-w != $w || $old-h != $h;
}
