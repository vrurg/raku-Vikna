NAME
====



`Vikna::Parent` – role providing parent object interface

DESCRIPTION
===========



The role implements essential parent object functionality with focus on Vikna needs.

ATTRIBUTES
==========



`Array:D @.strata`
------------------

Two-dimensional array of children. First dimension are strata whose indices are aliased with `StBack`, `StMain`, `StModal` enums. Second dimension are children bound to corresponding stratum. Order of children in a stratum array defines their Z-order when drawn on the parent widget.

METHODS
=======



`is-my-child($child)`
---------------------

Checks if `$child` is known by the parent object. If not then throws `X::NoChild`.

`elems(ChildStrata $stratum?)`
------------------------------

If `$stratum` parameter is defined returns number of children in the corresponding stratum. Otherwise returns number of all children in all strata.

`multi children(ChildStrata $stratum?, :$reverse, :lazy)`
---------------------------------------------------------

`multi children(ChildStrata $stratum?, :$reverse, :!lazy)`
----------------------------------------------------------

Returns children object. If `$stratum` is defined then returns only those bound to the requested stratum. With `:lazy` parameter returns a lazy sequence of children. Otherwise returns a list.

`add-child($child, ChildStrata:D $stratum = StMain)`
----------------------------------------------------

Adds a new child to the `$stratum`. Child's parent is set to the parent object with `set-parent` method.

`remove-child($child)`
----------------------

Removes a child if known, otherwise throws `X::NoChild`. Child's parent is reset to `Nil`.

`next-to($child, :$reverse, :$on-strata, :$loop)`
-------------------------------------------------

Returns a child object next to `$child` in Z-order. With `:on-strata` passes cross-stratum boundaries in `StBack` -> `StMain` -> `StModal` order. Otherwise only considers the stratum child is bound to. With `:loop` returns the first child if method is invoked for the last child in Z-order, with respect to `:on-strata`.

Uses `is-my-child` method to check if child is known.

`to-top($child)`
----------------

Moves a child to the top of Z-order. Only operates within child's stratum.

`to-bottom($child)`
-------------------

Moves a child to the bottom of Z-order. Only operates within child's stratum.

`is-topmost($child, :$on-strata)`, `is-bottommost($child, :$on-strata)`
-----------------------------------------------------------------------

Returns true if the child is on the top or bottom of Z-order respectively. With `:on-strata` both check if the condition is met globally.

`child-stratum($child --> ChildStrata)`
---------------------------------------

Returns the stratum the child is bound to. Returns `Nil` if the child is not known to the parent object.

`for-children(&code, :&pre, :&post, :$reverse, :$stratum)`
----------------------------------------------------------

Method iterates over children within a lock-protected loop. I.e. it is thread-safe children iteration.

`:pre` and `:post` code is executed before and after the loop correspondingly. `:reverse` causes it to iterate in reverse Z-order. With `:stratum` it iterates only over the specific stratum.

Nomal control flow routines `next` and `last` can be used within `&code`:

    self.for-children: -> $child {
        if $child.name ~~ $pattern {
            self.found-it($child);
            last
        }
    };

`children-protect(&code)`
-------------------------

Similarly to [`Lock`](https://docs.raku.org/type/Lock) `protect` method, lock-protects `&code`. The protection guarantees safety of operations with childrens.

**IMPORTANT!** None of the above mentioned methods, except for `for-children`, are lock protected! This is to avoid performance penalty of lock protection for cases where it is not needed. For example, when certain operation is only ever performed under event loop control.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

