use v6;
use Terminal::Print::Widget;
use Term::UI::Parent;
use Term::UI::Child;
unit class Term::UI::Widget is Terminal::Print::Widget is export;
also does Term::UI::Parent[::?CLASS];
also does Term::UI::Child;

has $.app is required;
has Bool:D $.auto-clear = False;
has Terminal::Print::Grid $!draw-grid;

submethod TWEAK(|c) {
    .add-child(self) with $!parent;
}

method create-child(Term::UI::Widget:U $wtype, |c) {
    $wtype.new: :$!app, :parent(self), |c;
}

method on-screen-resize {
    .on-screen-resize for @.children;
}

method grid {
    return $_ with $!draw-grid;
    nextsame
}

method clear {
    .clear for @.children;
    $.grid.clear;
}

method begin-draw {
    return if $!draw-grid;
    $!draw-grid = $!auto-clear ?? $.grid.new-from-self !! $.grid.clone;
}

method end-draw {
    self.replace-grid: $!draw-grid;
    $!draw-grid = Nil;
}

method redraw {
    self.begin-draw;
    .redraw for @.children;
    self.?draw;
    self.end-draw;
}

method composite {
    .composite(to => $.grid) for @.children;
    nextsame
}

method on-resize(:$old-w, :$old-h) {
    self.redraw;
}

method resize(Int:D :$w where * > 0 = $.w, Int:D :$h where * > 0 = $.h) {
    my $old-w = $.w;
    my $old-h = $.h;
    self.replace-grid: $.grid.clone(:$w, :$h);
    self.?on-resize(:$old-w, :$old-h) if $old-w != $w || $old-h != $h;
}
