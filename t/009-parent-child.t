use v6.e.PREVIEW;
use Test;

use Vikna::Parent;
use Vikna::Child;
use Vikna::Utils;
use Vikna::X;

plan 3;

class Child does Vikna::Child is Vikna::Object {
    has $.data;
}

class Parent does Vikna::Parent[Child] {
}

subtest "Basics" => {
    plan 8;
    my Child $c .= new;
    my Parent $p .= new;

    ok ($p.add-child: $c), "add-child returns truish value on success";
    nok ($p.add-child: $c), "add-child return falsish value for existing child";
    is $p.elems, 1, "double-add doesn't duplicate";

    for ^9 {
        $p.add-child: Child.new;
    }
    is $p.elems, 10, "plus 9 children makes it 10";
    $p.remove-child: $p.children[3];
    is $p.elems, 9, "a child has been removed";

    $p.to-top($c = $p.children[2]);
    is $p.children.tail, $c, "child moved to top";

    $p.to-bottom($c = $p.children[2]);
    is $p.children.head, $c, "child moved to bottom";

    is-deeply $p.children.map( *.parent ).list, ($p xx 9), "all parents are set";
}

subtest "Strata" => {
    plan 32;
    my Child $c .= new;
    my Parent $p .= new;

    $p.add-child: $c;
    is $p.child-stratum($c), StMain, "by default we add into main stratum";
    $p.add-child: $c, :stratum(StBack);
    is $p.elems, 1, "double-add doesn't duplicate";
    is $p.child-stratum($c), StMain, "duplicate insert doesn't change child stratum";
    $p.remove-child($c);
    is $p.elems, 0, "child removed";

    my $i = 0;
    for StMain, StModal, StBack -> $st {
        for ^3 {
            $p.add-child: Child.new(data => $i++), :stratum($st)
        }
    }
    is $p.elems, 9, 'all children added to strata';
    isa-ok $p.children, List, "children method returns a List";
    is-deeply $p.children.map( *.data ).list, (6, 7, 8, 0, 1, 2, 3, 4, 5), "children are sorted by stratum";
    is-deeply $p.children(:reverse).map( *.data ).list, (5, 4, 3, 2, 1, 0, 8, 7, 6), "children are reverse-sorted by stratum";

    isa-ok $p.children(:lazy), Seq, "lazy children returns a Seq";
    ok $p.children(:lazy).is-lazy, "lazy children Seq is lazy";
    is-deeply $p.children(:lazy).map( *.data ).list.eager, (6, 7, 8, 0, 1, 2, 3, 4, 5), "lazy children are sorted by stratum";
    is-deeply $p.children(:reverse, :lazy).map( *.data ).list.eager, (5, 4, 3, 2, 1, 0, 8, 7, 6), "lazy children are reverse-sorted by stratum";
    is-deeply $p.children(StModal, :lazy).map( *.data ).list.eager, (3, 4, 5), "lazy children iterates over a stratum";
    is-deeply $p.children(StModal, :lazy, :reverse).map( *.data ).list.eager, (5, 4, 3), "lazy children reverse-iterates over a stratum";

    is-deeply $p.children(StBack).map( *.data ).list, (6, 7, 8), "StBack stratum children";
    is $p.elems(StBack), 3, "StBack stratum elems";
    is-deeply $p.children(StMain).map( *.data ).list, (0, 1, 2), "StMain stratum children";
    is $p.elems(StMain), 3, "StMain stratum elems";
    is-deeply $p.children(StModal).map( *.data ).list, (3, 4, 5), "StModal stratum children";
    is $p.elems(StModal), 3, "StModal stratum elems";
    $p.remove-child($p.children[1]);
    is-deeply $p.children.map( *.data ).list, (6, 8, 0, 1, 2, 3, 4, 5), "children are sorted by stratum";
    is-deeply $p.children(StBack).map( *.data ).list, (6, 8), "StBack stratum after child removal";
    is $p.elems(StBack), 2, "StBack elems after child removal";
    is $p.elems(StMain), 3, "StMain number of children didn't change";
    is $p.elems(StModal), 3, "StModal number of children didn't change";
    throws-like { $p.remove-child(Child.new) }, X::NoChild, "removal of non-existing child throws";

    $p.to-top($p.children[3]);
    is-deeply $p.children(StMain).map( *.data).list, (0, 2, 1), "child moving to top inside its stratum";
    is-deeply $p.children.map( *.data).list, (6, 8, 0, 2, 1, 3, 4, 5), "child order after to-top operation";

    $p.to-bottom($p.children[6]);
    is-deeply $p.children(StModal).map( *.data).list, (4, 3, 5), "child moving to bottom inside its stratum";
    is-deeply $p.children.map( *.data).list, (6, 8, 0, 2, 1, 4, 3, 5), "child order after to-bottom operation";

    $c = Child.new(data => pi);
    $p.add-child($c, :stratum(StBack));
    ok $p.is-topmost($c), "last added child is the topmost one is its stratum";
    ok $p.is-bottommost($p.children[6]), "moved to bottom child is the bottommost one in its stratum";
}

subtest "Locking" => {
    plan 2;
    my $sync1 = Promise.new;
    my $sync2 = Promise.new;
    my Parent $p .= new;

    for ^100 {
        $p.add-child(Child.new(data => $_));
    }

    my $loop1-end;
    my $loop2-start;
    my @order;
    my @w = start {
                @order.push: "b1";
                $p.for-children: {
                    if $sync1.status ~~ Planned {
                        $sync1.keep(True);
                        await $sync2;
                        @order.push: "c1";
                    }
                }
                @order.push: "e1";
                $loop1-end = now;
            },
            start {
                await $sync1; # Make sure the first loop started
                @order.push: "b2";
                $sync2.keep(True);
                $p.for-children: {
                    $loop2-start = now unless $loop2-start;
                }
                @order.push: "e2";
            };

    await @w;

    ok $loop2-start > $loop1-end, "for-children loops are never running simultaneously";
    is-deeply @order, [|<b1 b2 c1 e1 e2>], "order of events is persistent";
}
