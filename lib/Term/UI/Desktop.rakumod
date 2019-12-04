use v6;
use Term::UI::Widget;
unit class Term::UI::Desktop is Term::UI::Widget is export;

method on-screen-resize {
}

method redraw {
    callsame;
    self.composite;
}
