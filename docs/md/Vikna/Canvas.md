NAME
====

`Vikna::Canvas` - here we draw

SYNOPSIS
========



    my $canvas = Vikna::Canvas.new(42,42);
    $canvas.invalidate(5, 5, 10, 10);
    for ^42 -> $y {
        $canvas.imprint(0, $y, "x" x 42, :fg<yellow>, :bg<blue>);
    }

    my $cell = $canvas.pick(4,4);
    say ~$cell; # char:"" fg:*transparent* bg:*transparent* style=0x00

    $cell = $canvas.pick(5,5);
    say ~$cell; # char:"x" fg:yellow bg:blue style=0x00

DESCRIPTION
===========



Inherits from [`Vikna::Object`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Object.md).

General information about canvas can be found in [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md).

Technical Details
-----------------

### Planes And Transparency

Canvas are implemented as a 4-plane rectangle consist of cells. Each cell represents a symbol. Each plane represent 4 properties of the symbol:

  * the character itself

  * foreground color

  * background color

  * style (see `VS*` constants in [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Utils.md))

Each of the four values can either be set or be transparent. This information is important to keep in mind when one canvas is imprinted into another. In this case, say, if a cell of the imprinted canvas has a character defined but three other properties are transparent then the destination cell in the underlying canvas will have the character changed but color and style information preserved. Or, another example, we can define say a "shadow" canvas where colors are set (for example, to dark grey fg and black bg) but style and characters are transparent. Then when imprinted into another canvas, it would create shadow are by only changing colors of the destination cells.

### Viewports

It is possible to use only a sub-rectangle of canvas by defining so called *viewport*. A *viewport* defined what area will be used when canvas is imprinted. This could speed up scrolling of big, rarely changing areas by pre-drawing the canvas and then setting it's viewport to the area which would exactly fit comparatively small widget. By moving a *viewport* within canvas we can create the effect of scrolling.

### Invalidations

Invalidations are kept as a list of rectangles. To speed up operations in cases when invalidations are mostly kept unchanged which is usually the normal way of how things happen, canvas build a so called *paintable mask*. It's a 2D array of boolean values (`int`, in fact) where a `true` at position `(x, y)` means that the cell at this position can be changed.

The mask is rebuild if the list of invalidations gets changed but not before any draw operation is requested.

### `Vikna::Canvas::Cell`

The frontend representing a cell withing canvas. While planes are low-level NQP objects, `Cell` provides a way for easy introspection of canvas content.

The class defined two attributes:

  * `Str $.char`

  * `L<Vikna::CAttr|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/CAttr.md>:D $.attr`

ATTRIBUTES
==========



### `L<Vikna::Rect|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md>:D $.geom`

Canvas geometry. Handles methods `x`, `y`, `w`, `h`.

Normally, canvas are positioned at 0,0 coordinates as internally own location means nothing to a canvas object.

### `$.inv-mark-color`

If defined cells covered by invalidation rectangles will have their background color set to this value. For debugging purposes only.

METHODS
=======



### `multi new($w, $h, *%c)`

### `multi new(:$w, :$h, *%c)`

Shortcut to quick create a canvas object with just its dimensions.

### `clone`

Creates a full copy for the canvas object.

### `dup(*%args)`

Create a new canvas which would inherit content from the canvas creating it.

### `clear`

Resets content to the all-transparent state.

### `multi imprint($x, $y, Str:D $line, L<C<Vikna::CAttr>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/CAttr.md>:D $attr, Int :$span?)`

### `multi imprint($x, $y, Str:D $line, :$fg, :$bg, :$style, Int :$span?)`

Imprints a `$line` into canvas at (`$x`,`$y`) position using the attributes provided. No more symbols will be imprinted than defined by `$span`.

### `imprint($x, $y, $w, $h, L<C<Vikna::CAttr>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/CAttr.md>:D $attr)`

### `imprint($x, $y, $w, $h, :$fg?, :$bg?, :$style?)`

Color and/or style fill of a rectangle.

### `imprint($x, $y, Vikna::Canvas:D :$from, :$skip-empy = True)`

Imprints canvas `$from` into self. If `$skip-empty` is *False* then transparency is disrespected and empty cells of `$from` canvas planes are forcibly copied over into self.

### `pick($x, $y, :$viewport)`

Pick a cell from specified position and returns a `Cell` instance. With `:viewport` parameter cell position is taken relatively to canvas viewport.

### `get-planes(\c-plane, \fg-plane, \bg-plane, \st-plane)`

Writes back low-level plane data into each respective argument. This method could be useful for testing and for screen driver implementations. Otherwise must be strictly avoided.

Plane content is implementation dependent.

### `multi viewport($x, $y, $w, $h)`

### `multi viewport(L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md>:D $rect)`

Sets canvas viewport rectangle.

### `multi viewport()`

Returns new canvas with viewport content. Note that if viewport rectangle is the canvas itself, then the original canvas object is returned.

### `multi invalidate()`

Invalidates the canvas entirely.

### `multi invalidate(L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md>:D $inv-rect)`

### `multi invalidate($x, $y, $w, $h)`

Invalidates a rectange on canvas.

### `is-paintable($x, $y)`

Returns true if cell at the specified position falls into invalidated area.

### `multi is-paintable-rect($x, $y, $w, $h)`

### `multi is-paintable-rect(L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md>:D $rect)`

Returns `True` if the specified rectangle is fully covered by invalidations.

### `multi add-inv-rect($x, $y, $w, $h)`

### `multi add-inv-rect(L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md>:D $rect`

Adds a rectangle to the list of invalidations

### `clear-inv-rects()`

Emties the list of invalidations effectively returning canvas to immutable state.

### `invalidations()`

Returns a list of invalidation rectangles.

### `multi fill(Str:D $char, :$fg, :$bg, :$style)`

Fills entire canvas with `$char` and the attributes.

### `vx`, `vy`, `vw`, `vh`

Viewport position and dimenstions.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md), [`Vikna::Object`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Object.md), [`Vikna::CAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/CAttr.md), [`Vikna::Color`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Color.md), [`Vikna::Point`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Point.md), [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Rect.md), [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Utils.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

