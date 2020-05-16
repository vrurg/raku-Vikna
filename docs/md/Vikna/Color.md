NAME
====



`Vikna::Color` - support for different formats of colors

SYNOPSIS
========



my $color = Vikna::Color.parse: '#abc'; # RGB 0xAA, 0xBB, 0xCC $color = Vikna::Color.parse: '42, 255, 13'; $color = Vikna::Color.parse: 'rgba: .1, .2, .3, .5';

DESCRIPTION
===========



Inherits from [`Color`](https://modules.raku.org/dist/Color).

This class function is to provide interface for working with string representation of colors. It supports colors in the following forms:

  * ANSI index: *123*

  * web: *#00aa80*, *#abc*

  * named: *green*

  * RGB triplet: *255,0,128*

  * RGB decimal triplet: *1, 0.1, .5*

  * prefixed form: *rgba: 1, 0.5, 0.9, 0.3*

For prefixed form knwon prefixes are *rgb*, *rgbd*, *rgba*, *rgbad*, *cmyk*, *hsl*, *hsla*, *hsv*, *hsva* - following the key names supported by [`Color`](https://modules.raku.org/dist/Color) class.

The only method to mention is `parse` which takes a string a returns either a `Vikna::Color` instance or a Nil if the color string is invalid. To be more precise, the object returned will have with one of `Vikna::Color` roles mixed in: [`Vikna::Color::Index`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/Index.md), [`Vikna::Color::Named`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/Named.md), [`Vikna::Color::RGB`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/RGB.md), [`Vikna::Color::RGBA`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/RGBA.md). The difference between the four is in the way they strigify by default and additional methods provided depending on the format.

Apparently, API provided by [`Coloar`](https://modules.raku.org/dist/Coloar) is available too.

Caching
-------

Color objects are cached internally to speed up color lookups. But it also means that same color object could be returned for two equivalent color strings. Nevertheless, the equivalence of the objects is not guaranteed due to limited cache size.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Color`](https://modules.raku.org/dist/Color), [`Color::Names`](https://modules.raku.org/dist/Color::Names), [`Vikna::Color::Index`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/Index.md), [`Vikna::Color::Named`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/Named.md), [`Vikna::Color::RGB`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/RGB.md), [`Vikna::Color::RGBA`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Color/RGBA.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

