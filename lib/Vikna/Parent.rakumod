use v6;
unit role Vikna::Parent[::ChldType] is export;

has @.children;

method add-child(ChldType:D $child) {
    # note "ADDING CHILD ", $child.WHICH;
    @!children.push: $child;
}

method remove-child(ChldType:D $child) {
    my \child := $child<>;
    @.children .= grep(! *<> =:= child);
}

method to-top(ChldType:D $child) {
    my \child := $child<>;
    self.remove-child($child);
    self.add-child($child);
}

method to-bottom(ChldType:D $child) {
    my \child := $child<>;
    @!children = flat $child, @!children.grep: ! *<> =:= child;
}
