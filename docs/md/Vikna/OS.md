NAME
====



`Vikna::OS` - base role for OS-specific layer class

ATTRIBUTES
==========



### [`Vikna::Screen`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Screen.md) `$.screen`

Screen driver.

REQUIRED METHODS
================

### `build-screen()`

Method must construct and return a [`Vikna::Screen`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Screen.md) object to initialize `$.screen`. See [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish) for lazy attributes implementation.

### `inputs()`

Method is expected to return a list of [`Vikna::EventEmitter`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventEmitter.md) objects for each OS-provided input device like a mouse or a keyboard.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Classes`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Classes.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

