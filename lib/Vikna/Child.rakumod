use v6.e.PREVIEW;
use Vikna::Parent;
unit role Vikna::Child is export;

has $.parent;

submethod TWEAK(:$parent, |) {
    with $parent {
        .add-child(self);
    }
}

method set-parent($parent --> Nil) {
    self.?reparent($!parent, $parent);
    $!parent = $parent;
}
