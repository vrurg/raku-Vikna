use v6.e.PREVIEW;
unit role Vikna::Parent[::ChldType];

has $!children-lock = Lock.new;
has @.children;

method add-child(ChldType:D $child) {
    $!children-lock.protect: {
        if @!children.grep: * === $child {
            Nil
        }
        else {
            @!children.push: $child;
            $child.set-parent(self);
            $child
        }
    }
}

method remove-child(ChldType:D $child) {
    $!children-lock.protect: {
        @!children .= grep: * !=== $child;
        $child.set-parent(Nil);
        $child
    }
}

method to-top(ChldType:D $child --> Nil) {
    $!children-lock.protect: {
        @!children = flat @!children.grep( * !=== $child ), $child;
    }
}

method to-bottom(ChldType:D $child --> Nil) {
    $!children-lock.protect: {
        @!children = flat $child, @!children.grep:  * !=== $child;
    }
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
