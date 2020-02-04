use v6.e.PREVIEW;
use Test;

use Vikna::Parent;
use Vikna::Child;

plan 1;

class Child does Vikna::Child {
}

class Parent does Vikna::Parent[Child] {
}

subtest "Basics" => {
    plan 6;
    my Child $c .= new;
    my Parent $p .= new;

    $p.add-child: $c;
    $p.add-child: $c;
    is $p.children.elems, 1, "Double-add doesn't duplicate";

    for ^9 {
        $p.add-child: Child.new;
    }
    is $p.children.elems, 10, "plus 9 children makes it 10";
    $p.remove-child: $p.children[3];
    is $p.children.elems, 9, "a child has been removed";

    $p.to-top($c = $p.children[2]);
    is $p.children.tail, $c, "child moved to top";

    $p.to-bottom($c = $p.children[2]);
    is $p.children.head, $c, "child moved to bottom";

    is-deeply $p.children.map( *.parent ).list, ($p xx 9), "all parents are set";
}
