use v6.e.PREVIEW;
unit role Vikna::Parent[::ChldType];

use Vikna::Utils;
use Vikna::X;

my class RegisteredChild {
    has $.child is required;
    has ChildStrata:D $.stratum is required;
}

has $!strata-lock = Lock::Async.new;
has Array:D @.strata;
has %!registry;

submethod TWEAK(|) {
    @!strata[$_] = [] for StBack, StMain, StModal;
}

method is-my-child($child) {
    %!registry{$child.id} // X::NoChild.new(:obj(self), :$child).throw
}

method elems(ChildStrata $stratum?) {
    with $stratum {
        @!strata[$stratum].elems
    }
    else {
        [+] @!strata.map({.elems});
    }
}

proto method children(ChildStrata $?, |) {*}
multi method children(ChildStrata $stratum?, :$reverse?, :$lazy where {.not} --> Positional:D) {
    my @st = $stratum // ChildStrata.enums.map({.value}).sort;
    @st = @st.reverse if $reverse;
    @st.map({
        slip ($reverse ?? @!strata[$_].reverse !! @!strata[$_])
    }).list
}

multi method children(ChildStrata $stratum?, :$reverse?, :$lazy! where {.so}) {
    my @st = $stratum // ChildStrata.enums.map({.value}).sort;
    @st = @st.reverse if $reverse;
    lazy gather {
        for @st -> $sti {
            ($reverse ?? @!strata[$sti].reverse !! @!strata[$sti]).map: { take $_ };
        }
    }
}

method add-child(ChldType:D $child, ChildStrata:D :$stratum = StMain) {
    return Nil if %!registry{$child.id};
    @!strata[$stratum].push: $child;
    %!registry{$child.id} = RegisteredChild.new: :$child, :$stratum;
    $child.set-parent(self);
    $child
}

method remove-child(ChldType:D $child) {
    (my $regc = %!registry{$child.id}:delete) // X::NoChild.new(:obj(self), :$child).throw;
    .STORE: .grep( * !=== $child ) given @!strata[$regc.stratum];
    $child.set-parent(Nil);
    $child
}

method next-to(ChldType:D $child, :$reverse?, :$on-strata?, :$loop?) {
    $.is-my-child: $child;
    my @children;
    if $on-strata {
        @children = self.children: :$reverse
    }
    else {
        @children = self.children: %!registry{$child.id}.stratum, :$reverse
    }

    # When looping it's enough to have the one copy of the first child after the actually last one.
    if $loop {
        .push: .head with @children;
    }

    my $found-child = False;
    for @children -> $sib {
        if $found-child {
            return $sib
        }
        else {
            $found-child = $child === $sib;
        }
    }
    die "INTERNAL: Child " ~ $child.name ~ " is registered on parent " ~ $.name ~ " but not in the list of children!"
}

method to-top(ChldType:D $child --> Nil) {
    (my $regc = %!registry{$child.id}) // X::NoChild.new(:obj(self), :$child).throw;
    @!strata[$_] = (flat @!strata[$_].grep( * !=== $child ), $child).Array given $regc.stratum;
}

method to-bottom(ChldType:D $child --> Nil) {
    (my $regc = %!registry{$child.id}) // X::NoChild.new(:obj(self), :$child).throw;
    @!strata[$_] = (flat $child, @!strata[$_].grep:  * !=== $child).Array with $regc.stratum;
}

method is-topmost(ChldType:D $child, :$on-strata? --> Bool:D) {
    return @!strata.map( { .Slip } ).tail === $child if $on-strata;

    (my $regc = %!registry{$child.id}) // X::NoChild.new(:obj(self), :$child).throw;
    @!strata[$regc.stratum].tail === $child
}

method is-bottommost(ChldType:D $child, :$on-strata? --> Bool:D) {
    return @!strata.map( { .Slip } ).head === $child if $on-strata;

    (my $regc = %!registry{$child.id}) // X::NoChild.new(:obj(self), :$child).throw;
    @!strata[$regc.stratum].head === $child
}

method child-stratum(ChldType:D $child --> ChildStrata) {
    with %!registry{$child.id} {
        .stratum
    }
    else {
        Nil
    }
}

method for-children(&code, :&pre?, :&post?, :$reverse?, ChildStrata :$stratum? --> Nil) {
    await $!strata-lock.lock;
    LEAVE $!strata-lock.unlock;

    .() with &pre;
    for self.children($stratum, :$reverse, :lazy) {
        &code($_)
    }
    .() with &post;
}

method children-protect(&code) {
    $!strata-lock.protect: &code
}
