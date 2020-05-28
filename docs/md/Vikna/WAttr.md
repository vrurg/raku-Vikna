NAME
====



`Vikna::WAttr` - widget attributes

DESCRIPTION
===========



Inherits from [Vikna::CAttr](Vikna::CAttr).

Class represents default widget attributes.

ATTRIBUTES
==========



### `$.pattern`

Background pattern of a widget. Interpretation of this attribute depends on a particular widget. But [`Vikna::Widget`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Widget.md) defines it as a string which fills the background. Say, if set to *'.'* then the background will be filled with dots.

ROUTINES
========



### `multi sub wattr($fg, $bg?, $style?, $pattern?)`

### `multi sub wattr(:$fg, :$bg?, :$style?, :$pattern?)`

Shortcut to create a `Vikna::WAttr` instance.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md),

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

