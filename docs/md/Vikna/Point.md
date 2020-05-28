NAME
====



`Vikna::Point` - geometric point type

SYNOPSIS
========



my $p1 = Vikna::Point(13, 42); my $p2 = Vikna::Point(1, 1); my $p3 = $p1 + $p2;

DESCRIPTION
===========



Implements basic point operations required by the framework.

Does [`Vikna::Coord`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Coord.md).

METHODS
=======



`multi new(Int:D $x, Int:D $y, *%c)`
------------------------------------

Shortcut to `Vikna::Point.new(:$x, :$y)` way of creating a new point object.

Also, `Vikna::Point(...args...)` is equivalent to `Vikna::Point.new(...args...)`.

`multi relative-to(Int:D $x, Int:D $y)`
---------------------------------------

`multi relative-to(Vikna::Coord:D $point)`
------------------------------------------

Returns a new point object which represents a difference between `self` and the coordinates in the argument(s).

Consider it a vector subtraction.

`multi aboslute(Int:D $x, Int:D $y)`
------------------------------------

`multi absolute(Vikna::Coord:D $point)`
---------------------------------------

Given that `self` represents a relative point, creates a new point object which represent position of `self` in the coordinate system to which argument(s) belong.

Consider it a vector addition.

`Str`
-----

Returns a string representation of the point.

`gist`
------

Same as `Str`

OPERATORS
=========



`infix:<+>`, `infix:<->`
------------------------

Vector addition and subtraction of two points.

SEE ALSO
========

[Vikna](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [Vikna::Manual](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md), [Vikna::Coord](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Coord.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

