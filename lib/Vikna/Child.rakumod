use v6.e.PREVIEW;
use Vikna::Parent;
unit role Vikna::Child is export;

has $.parent;

method set-parent($parent --> Nil) {
    self.?reparent($!parent, $parent);
    $!parent = $parent;
}
