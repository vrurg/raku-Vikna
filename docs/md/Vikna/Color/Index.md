NAME
====



`Vikna::Color::Index` - represents indexed color

ATTRIBUTES
==========



### `Int $.index`

The index used to create the object.

METHODS
=======



### `method rgb-by-index(Int:D $idx)`

Takes an ANSI color index and returns its RGB representation as a [`Hash`](https://docs.raku.org/type/Hash) with keys `r`, `g`, `b`. If no such index exists then an empty hash is returned.

*Note* that the representation is taken from file *resources/color-index.json*.

Stringifies into index.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Color`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

