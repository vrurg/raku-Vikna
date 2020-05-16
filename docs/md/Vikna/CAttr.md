NAME
====



`Vikna::CAttr` - on screen symbol attributes

DESCRIPTION
===========



Class defines basic attributes of a symbol on screen: it's foreground and background colors, and style.

ATTRIBUTES
==========



### `$.fg`

Foreground color

### `$.bg`

Bacground color

### `Int $.style`

Style of the symbol. See `VS*` constants in [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Utils.md).

### `%.Profile`

Cached representation of the attribute suitable for passing into methods like [`Vikna::Canvas`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md)`::imprint`.

METHODS
=======



### `new(*%c)`

### `clone(*%c)`

### `dup(*%c)`

All three methods preserve their usual meaning with one nuance: if `style` key is passed in `%c` profile then it gets normalized using `to-style` routine from [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Utils.md).

### `bold()`, `italic()`, `underline()`

Methods return *True* if corresponding style is set.

### `transparent()`

Returns *True* style is transparent.

### `style-char()`

Returns style representation as a single char. For example, for non-transparent style if nothing is set it would be just space character *" "* (code *0x20* which is the value of `VSNone` constant). For bold which is represented as `VSBase +| VSBold` it will be exclamation mark *"!"* (code *0x21*).

### `styles()`

Returns a list of style `VS*` constants.

ROUTINES
========



### `multi sub cattr($fg, $bg?, $style?)`

### `multi sub cattr(:$fg, :$bg, :$style)`

A shortcut to create a new `Vikna::CAttr` instance.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md),

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

