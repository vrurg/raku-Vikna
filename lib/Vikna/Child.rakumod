use v6.e.PREVIEW;
use Vikna::Parent;
unit role Vikna::Child;

has $.parent;

method set-parent($parent) {
    $!parent = $parent;
}
