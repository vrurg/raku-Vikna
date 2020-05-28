NAME
====



`Vikna::Rect` - the rectangle type

SYNOPSIS
========



    my $rect = Vikna::Rect(10, 5, 42, 13);
    my $rect2 = $rect.move-by(-5, 5);       # 5, 10, 42, 13
    $rect.contains($rect2);                 # False

DESCRIPTION
===========



Does [`Vikna::Coord`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Coord.md).

Represents a rectangle object.

ATTRIBUTES
==========



### `UInt:D $.w`, `UInt:D $.h`

Width and height of the rectangle, respectively.

### `Int $.right`, `Int $.bottom`

Right and bottom widget boundaries.

METHODS
=======



### `new($x, $y, $w, $h)`

A shortcut to `new(:$x, :$y, :$w, :$h)`. The class also supports a callable for of instantiation, as shown in [SYNPOSIS](#SYNPOSIS).

### `dup(*%twiddles)`

Duplicates a rectangle instance using `new`.

### `Array()`

Coerces a rectangle into an array of it's coordinates and dimensions.

### `List()`

Similar to `Array` method above, but coerce into a `List`.

### `coords()`

An alias to `List` method.

### `multi overlap($x, $y, $w, $h)`

### `multi overlap(Vikna::Rect:D $rec)`

Returns *True* if two rectangles overlap.

### `multi clip-by(Vikna::Rect:D $into, :$copy?)`

### `multi clip-by(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h)`

Clip a rectangle by `$into`.

### `multi dissect(Vikna::Rect:D $by)`

### `multi dissect(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h)`

Dissect a rectangle with `$by`. It means that `$by` is cut out of the rectangle we dissect and the remaining area is dissected into sub-rectangles.

### `multi dissect(@by)`

Dissect by a list of rectangles.

### `multi contains(Int:D $x, Int:D $y)`

### `multi contains(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h)`

### `multi contains(Vikna::Coord:D $point)`

### `multi contains(Vikna::Rect:D $rect)`

Returns *True* is the argument is contained by rectangle.

### `multi relative-to(Int:D $x, Int:D $y)`

### `multi relative-to(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h, :$clip = False)`

### `multi relative-to(Vikna::Coord:D $point)`

### `multi relative-to(Vikna::Rect:D $rect, :$clip = False)`

Takes current rectangle and returns a new one which coordinates are relative to coordinates of `$rect`. With `:clip` clips the new rectangle by `$rect`.

### `multi absolute(Int:D $x, Int:D $y)`

### `multi absolute(Vikna::Rect:D $rec, :$clip = False)`

Assuming that rectangle coordinates are relative to the argument, transforms them into the "absolute" values and returns a new rectangle. With `:clip` it is cliped by `$rect`.

### `multi move(Int:D $x, Int:D $y)`

### `multi move(Vikna::Coord:D $point)`

Returns a new rectangle with it's origin set to the argument.

### `multi move-by(Int:D $dx, Int:D $dy)`

### `multi move-by(Vikna::Coord:D $delta)`

Returns a new rectangle shifted by the argument.

### `Str()`

### `gist()`

Strigify rectangle.

OPERATORS
=========



### `infix:<+>(Vikna::Rect:D $r, Vikna::Coord:D $delta)`

Same as `move-by`.

### `infix:<==>(Vikna::Rect:D $a, Vikna::Rect:D $b)`

Returns *True* if both rectangles have same origins and dimensions.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md), [`Vikna::Classes`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Classes.md), [`Vikna::Coord`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Coord.md), [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Point.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

