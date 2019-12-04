use v6;
use Term::UI::Parent;
unit role Term::UI::Child is export;

has $.parent;

method set-parent($parent --> Nil) {
    self.?reparent($!parent, $parent);
    $!parent = $parent;
}
