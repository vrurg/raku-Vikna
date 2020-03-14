use v6.e.PREVIEW;
use Vikna::Parent;
use Vikna::Object;
unit role Vikna::Child;

method id {...}

has Vikna::Parent $.parent;

method set-parent($parent) {
    $!parent = $parent;
}

method has-parent { ? $!parent }
