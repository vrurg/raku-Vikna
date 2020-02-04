use v6.e.PREVIEW;
unit role Vikna::Parent[::ChldType];

has $!children-lock = Lock.new;
has @.children;

method add-child(ChldType:D $child) {
    return Nil if @!children.grep: * === $child;
    @!children.push: $child;
    $child.set-parent(self);
}

method remove-child(ChldType:D $child) {
    @!children .= grep: * !=== $child;
    $child.set-parent(Nil)
}

method to-top(ChldType:D $child) {
    @!children = flat @!children.grep( * !=== $child ), $child;
}

method to-bottom(ChldType:D $child) {
    @!children = flat $child, @!children.grep:  * !=== $child;
}

method for-children(&code, :&pre?, :&post? --> Nil) {
    $!children-lock.lock;
    LEAVE $!children-lock.unlock;

    .() with &pre;
    &code($_) for @!children;
    .() with &post;
}

method children-protect(&code) {
    $!children-lock.protect: &code
}
