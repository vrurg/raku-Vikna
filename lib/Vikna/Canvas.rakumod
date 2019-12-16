use v6.e.PREVIEW;

# Canvas coordinates might not coniside with screen or widget coords as canvas can be bigger in size. Viewport defines
# what will be outputted.
#
# Output operations thus act on viewport coordinates. Drawing operations act on canvas coordinates.

# use OO::Monitors;
use Vikna::Object;

unit class Vikna::Canvas;
also is Vikna::Object;

use nqp;
use Terminal::Print::Commands;
use Terminal::ANSIColor;
use AttrX::Mooish;
use Vikna::X;
use Vikna::Rect;
use Vikna::Point;
use Vikna::Color;
use Vikna::Utils;


our class Cell {
    has Str $.char where { !.defined || .chars == 0 | 1 };
    has BasicColor $.fg;
    has BasicColor $.bg;

    multi method FROM(::?CLASS:D: |c) { self.WHAT.FROM(|c) }

    # This method returns the char unmodified if no colors defined.
    multi method FROM(::?CLASS:U: Str:D $char where *.chars == 0 | 1, :$fg?, :$bg?, *%c) {
        if $fg || $bg {
            self.new: :$char, :$fg, :$bg, |%c
        }
        else {
            $char
        }
    }
    multi method FROM(::?CLASS:U: Any:U, *%c) { %c ?? Cell.new: |%c !! Any }

    multi method FROM(::?CLASS:U: Cell:D $cell, *%c) {
        $cell.clone: |%c;
    }

    multi method FROM(::?CLASS:U: *%c) {
        self.new: |%c
    }

    method Str { $!char }
}

has Vikna::Rect:D $.geom is required;
has @.cells is mooish(:lazy, :clearer);
has Mu $!paintable-mask; # is mooish(:lazy, :clearer);
has Bool $!paintable-expired = True;

# Viewport
has Vikna::Rect $!vp-geom is mooish(:lazy, :clearer);

has $!inv-rects;

multi method new(Dimension $w, Dimension $h, *%c) {
    self.new: geom => Vikna::Rect.new(:0x, :0y, :$w, :$h), |%c
}

multi method new(Dimension :$w, Dimension :$h, *%c) {
    self.new: geom => Vikna::Rect.new(:0x, :0y, :$w, :$h), |%c
}

multi submethod TWEAK(:@from-cells where ?*, *%c) {
    if @from-cells {
        for @from-cells[ ^min( self.h, +@from-cells ) ].kv -> $i, @row {
            my $w = self.w min +@row;
            @!cells[$i].splice( 0, $w, @row[^$w]);
        }
    }
    nextsame
}

multi submethod TWEAK {
    $!inv-rects := nqp::list();
}

method !build-vp-geom {
    $!geom.clone
}

method build-cells {
    [ Nil xx $.w ] xx $.h
}

method new-from-self(::?CLASS:D: *%args) {
    self.create: self.WHAT, geom => $!geom.clone, vp-geom => $!vp-geom.clone, |%args;
}

method dup(::?CLASS:D: *%args) {
    self.create: self.WHAT, geom => $!geom.clone, vp-geom => $!vp-geom.clone, :from-cells(@!cells), |%args;
}

method clear {
    $.clear-cells
}

multi method set-cell(UInt:D $x where * < $.w, UInt:D $y where * < $.h, Str:D $char where *.chars == 1) {
    @!cells[$y][$x] = $char;
}

multi method set-cell(UInt:D $x where * < $.w, UInt:D $y where * < $.h, Cell:D $c) {
    @!cells[$y][$x] = $c
}

multi method set-cell(UInt:D $x where * < $.w, UInt:D $y where * < $.h, *%c) {
    @!cells[$y][$x] = Cell.new: |%c;
}

proto method imprint(UInt:D $x where * < $.w, UInt:D $y where * < $.h, |) {
    {*}
}

# a string
multi method imprint($x, $y, $line, :$fg? is copy, :$bg? is copy, Int :$span?)
{
    my $len = min $.w, $span // $line.chars;
    my @chars = $line.substr(0, $len).comb;
    # A color can be a triplet of color channels.
    $fg = $fg.join(",") if $fg ~~ Positional:D;
    $bg = $fg.join(",") if $bg ~~ Positional:D;
    my $use-Cell = $fg || $bg;
    my @row := @!cells[$y];
    for @chars.kv -> $i, $char {
        my $cx := nqp::add_i($x, $i);
        next unless $.is-paintable($cx, $y);
        # Condition branches must be the same as set-cell method bodies. Avoiding extra method call for perofrmance.
        if $use-Cell {
            @row[$cx] = Cell.new: :$char, :$fg, :$bg;
        }
        else {
            @row[$cx] = $char;
        }
    }
}

# fill a rect with color
multi method imprint($x, $y, $w, $h, :$fg? is copy, :$bg? is copy) {
    for $y..^(min $.h, $y + $h) -> $row {
        my @row := @!cells[$row];
        for $x..^(min $.w, $x + $w) -> $col {
            next unless $.is-paintable($col, $row);
            @row[$col] = Cell.FROM( @row[$col], :$fg, :$bg );
        }
    }
}

# a string but preserve colors
multi method imprint($x, $y, Str:D $line, Bool :$text-only! where *) {
    my @row = @!cells[$y];
    my @chars = $line.comb;
    for ^(min $.w - $x, +@chars) -> $i {
        my $cx = $x + $i;
        next if $.is-paintable( $cx, $y );
        nqp::stmts(
            ( my \cell = @row[ $cx + $i ] ),
            ( my $char = @chars[$i] // '' ),
            nqp::if(
                nqp::istype( cell, Cell ),
                ( cell = Cell.FROM( cell, :$char ) ),
                ( cell = $char )
            )
        );
    }
}

# Copy from another canvas
multi method imprint($x, $y, ::?CLASS:D $from) {
    my @from-cells := $from.cells;
    nqp::stmts(
        (my $from-y = $from.h),
        nqp::if($from-y > (my $hh := $.h - $y), ($from-y = $hh)),
        nqp::while(
            nqp::isge_i(--$from-y, 0),
            nqp::stmts(
                (my $to-y := $y + $from-y),
                (my @from-row := @from-cells[$from-y]),
                (my @row := @!cells[$to-y]),
                (my $from-x = $from.w),
                nqp::if($from-x > (my $ww = $.w - $x), ($from-x = $ww)),
                nqp::while(
                    nqp::isge_i(--$from-x, 0),
                    nqp::stmts(
                        (my $to-x := $x + $from-x),
                        nqp::if(
                            $.is-paintable($to-x, $to-y),
                            nqp::stmts(
                                (my $from-cell := @from-row[$from-x]),
                                nqp::if(
                                    nqp::istype($from-cell, Cell),
                                    nqp::stmts(
                                        (my $fg := $from-cell.fg),
                                        (my $bg := $from-cell.bg),
                                        nqp::if(
                                            $fg || $bg,
                                            (@row[$to-x] = Cell.FROM($from-cell || @row[$to-x], :$fg, :$bg)),
                                            nqp::if($from-cell, (@row[$to-x] = $from-cell))
                                        ),
                                    ),
                                    nqp::if($from-cell, (@row[$to-x] = $from-cell))
                                )
                            )
                        )
                    )
                )
            )
        )
    );
}

#| With four parameters viewport is been set.
multi method viewport(UInt:D $x, UInt:D $y, Int:D $w where * > 0, Int:D $h where * > 0 --> Nil) {
    $.throw: X::Canvas::BadViewport, :$x, :$y, :$w, :$h unless $!geom.contains($x, $y, $w, $h);
    $!vp-geom = $.create: Vikna::Rect, :$x, :$y, :$w, :$h;
}

multi method viewport(Vikna::Rect:D $rect) {
    $.throw: X::Canvas::BadViewport, :$rect unless $!geom.contains($rect);
    $!vp-geom = $rect.clone;
}

#| Returns array of rows of cells
multi method viewport( --> Vikna::Canvas ) {
    my ($vx, $vy, $vw, $vh) = $!vp-geom.x, $!vp-geom.y, $!vp-geom.w, $!vp-geom.h;
    my @viewport = [] xx $vh;
    for ^$vh -> $vrow {
        my @row := @!cells[$vy + $vrow];
        my @vrow := @viewport[$vrow];
        for ^$vw -> $vcol {
            my \cell = @row[$vx + $vcol];
            @vrow[$vcol] = cell ~~ Cell ?? cell.clone !! cell;
        }
    }
    $.create: Vikna::Canvas, geom => $!vp-geom, from-cells => @viewport
}

multi method invalidate(::?CLASS:D:) {
    $.invalidate(0, 0, $.w, $.h)
}
multi method invalidate(::?CLASS:D: Vikna::Rect:D $rect) {
    $.add-inv-rect($rect) unless $.is-paintable-rect($rect);
}
multi method invalidate(+@rect where *.elems == 4) {
    $.add-inv-rect(@rect)
        unless $.is-paintable-rect(@rect);
}

method is-paintable(::?CLASS:D: $x, $y) {
    # By default the whole canvas is non-paintable unless invalidated rects are added.
    my $w := $.w;
    return False unless    nqp::isle_i($x, $w)
                        && nqp::isle_i($y, $.h)
                        && nqp::elems($!inv-rects);
    self!build-paintable-mask if $!paintable-expired;
    nqp::atpos_i(nqp::decont($!paintable-mask), nqp::add_i(nqp::mul_i($w, $y), $x))
}

#| See if the whole rectange is inside another invalidated rectangle.
multi method is-paintable-rect(UInt:D $x, UInt:D $y, Dimension $w, Dimension $h) { $.is-paintable( Vikna::Rect.new: :$x, :$y, :$w, :$h ) }
multi method is-paintable-rect(::?CLASS:D: Vikna::Rect:D $rect) {
    # XXX Optimization is possible: for small rectangles it could be faster to test all rectange cells against the
    # paintable mask. It's only a matter of determining at what ratio of the number of points to the number of
    # invalidated rects such optimization would be effective.
    my @dissects = $rect;

    my \iter = nqp::iterator($!inv-rects);
    nqp::while(
        nqp::if( iter, +@dissects ),
        nqp::stmts(
            nqp::shift(iter),
            ( my $inv-rec := nqp::iterval(iter) ),
            ( my $ds-cnt = 1 + @dissects ),
            nqp::while(
                --$ds-cnt,
                ( @dissects.append: @dissects.shift.dissect( $inv-rec ) )
            )
        )
    );
    !@dissects
}

method !build-paintable-mask {
    $!paintable-mask := nqp::list_i();
    my $y = $.h;
    $*VIKNA-APP.debug("build-paintable-mask from ", nqp::elems($!inv-rects), " rects");
    nqp::while(
        nqp::isge_i(--$y, 0),
        nqp::stmts(
            (my $x = $.w),
            (my $yshift = $y * $.w),
            nqp::while(
                nqp::isge_i(--$x, 0),
                nqp::stmts(
                    (my $i = nqp::elems($!inv-rects)),
                    (my $paintable := nqp::unbox_i(0)),
                    nqp::while(
                        nqp::if(nqp::isge_i(--$i, 0), !$paintable),
                        nqp::stmts(
                            (my \inv-rect := nqp::atpos($!inv-rects, $i)),
                            ($paintable := nqp::istrue(inv-rect.contains($x, $y)))
                        )
                    ),
                    (my $pos := $yshift + $x),
                    (nqp::bindpos_i($!paintable-mask, $pos, $paintable)),
                )
            )
        )
    );
    $!paintable-expired = False;
}

# multi method add-inv-rect(UInt:D $x, UInt:D $y, UInt:D $w where * > 0, UInt:D $h where * > 0) {
#     nqp::push( $!inv-rects, Vikna::Rect.new: $x, $y, $w, $h );
# }

multi method add-inv-rect(+@rect where *.elems == 4) {
    $*VIKNA-APP.debug: "Add inv rect \@: ", @rect;
    nqp::push( $!inv-rects, Vikna::Rect.new: |@rect );
    $!paintable-expired = True;
    # self!clear-paintable-mask;
}

multi method add-inv-rect(Vikna::Rect:D $r) {
    $*VIKNA-APP.debug: "Add inv rect: ", $r;
    nqp::push( $!inv-rects, $r );
    $!paintable-expired = True;
    # self!clear-paintable-mask;
}

method clear-inv-rect {
    $!inv-rects := nqp::list()
}

method invalidates {
    nqp::hllize($!inv-rects)
}

multi method fill(Str:D $char where *.chars == 1, BasicColor :$fg?, BasicColor :$bg?) {
    my $line = $char x $.w;
    for ^$.h -> $row {
        $.imprint(0, $row, $line, :$fg, :$bg);
    }
}

method x { $!geom.x }
method y { $!geom.y }
method w { $!geom.w }
method h { $!geom.h }
