NAME
====



`Vikna::Color::Named` - a role representing named colors

DESCRIPTION
===========



Stringifies into the given color name.

ATTRIBUTES
==========



### `Str:D $.name`

Color name used to create the object.

METHODS
=======



### `rgb-by-name(Str:D $name)`

If color with given `$name` is known then return a [`Hash`](https://docs.raku.org/type/Hash) with keys `r`, `g`, `b`. Otherwise returns empty hash.

### `known-color-name($name)`

Returns *True* if color `$name` is known.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md), [`Vikna::Color`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Color.md), [`Color::Names`](https://modules.raku.org/dist/Color::Names)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

