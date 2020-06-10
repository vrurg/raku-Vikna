use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Parent> – role providing parent object interface

=DESCRIPTION

The role implements essential parent object functionality with focus on Vikna needs.

=ATTRIBUTES

=head2 C<Array:D @.strata>

Two-dimensional array of children. First dimension are strata whose indices are aliased with C<StBack>, C<StMain>,
C<StModal> enums. Second dimension are children bound to corresponding stratum. Order of children in a stratum array
defines their Z-order when drawn on the parent widget.

=METHODS

=head2 C<is-my-child($child)>

Checks if C<$child> is known by the parent object. If not then throws C<X::NoChild>.

=head2 C<elems(ChildStrata $stratum?)>

If C<$stratum> parameter is defined returns number of children in the corresponding stratum. Otherwise returns number of
all children in all strata.

=head2 C<multi children(ChildStrata $stratum?, :$reverse, :lazy)>
=head2 C<multi children(ChildStrata $stratum?, :$reverse, :!lazy)>

Returns children object. If C<$stratum> is defined then returns only those bound to the requested stratum. With C<:lazy>
parameter returns a lazy sequence of children. Otherwise returns a list.

=head2 C<add-child($child, ChildStrata:D $stratum = StMain)>

Adds a new child to the C<$stratum>. Child's parent is set to the parent object with C<set-parent> method.

=head2 C<remove-child($child)>

Removes a child if known, otherwise throws C<X::NoChild>. Child's parent is reset to C<Nil>.

=head2 C<next-to($child, :$reverse, :$on-strata, :$loop)>

Returns a child object next to C<$child> in Z-order. With C<:on-strata> passes cross-stratum boundaries in C<StBack> ->
C<StMain> -> C<StModal> order. Otherwise only considers the stratum child is bound to. With C<:loop> returns the first
child if method is invoked for the last child in Z-order, with respect to C<:on-strata>.

Uses C<is-my-child> method to check if child is known.

=head2 C<to-top($child)>

Moves a child to the top of Z-order. Only operates within child's stratum.

=head2 C<to-bottom($child)>

Moves a child to the bottom of Z-order. Only operates within child's stratum.

=head2 C<is-topmost($child, :$on-strata)>, C<is-bottommost($child, :$on-strata)>

Returns true if the child is on the top or bottom of Z-order respectively. With C<:on-strata> both check if the
condition is met globally.

=head2 C<<child-stratum($child --> ChildStrata)>>

Returns the stratum the child is bound to. Returns C<Nil> if the child is not known to the parent object.

=head2 C<for-children(&code, :&pre, :&post, :$reverse, :$stratum)>

Method iterates over children within a lock-protected loop. I.e. it is thread-safe children iteration.

C<:pre> and C<:post> code is executed before and after the loop correspondingly. C<:reverse> causes it to iterate in
reverse Z-order. With C<:stratum> it iterates only over the specific stratum.

Nomal control flow routines C<next> and C<last> can be used within C<&code>:

    self.for-children: -> $child {
        if $child.name ~~ $pattern {
            self.found-it($child);
            last
        }
    };

=head2 C<children-protect(&code)>

Similarly to L<C<Lock>|https://docs.raku.org/type/Lock> C<protect> method, lock-protects C<&code>. The protection guarantees safety of operations with
childrens.

B<IMPORTANT!> None of the above mentioned methods, except for C<for-children>, are lock protected! This is to avoid
performance penalty of lock protection for cases where it is not needed. For example, when certain operation is only
ever performed under event loop control.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

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
        # XXX Perhaps a number of keys in %!registry?
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
    self.is-my-child: $child;
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
