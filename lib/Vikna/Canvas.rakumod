use v6;

# Canvas coordinates might not coniside with screen or widget coords as canvas can be bigger in size. Viewport defines
# what will be outputted.
#
# Output operations thus act on viewport coordinates. Drawing operations act on canvas coordinates.

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

my class Cell {
    has Str $.char where { !.defined || .chars == 0 | 1 };
    # Colors
    has Str $.fg;
    has Str $.bg;
    has $!stringified;

    my %color-cache = '' => '';
    our $reset-color = color('reset');

    method !stringify {
        $!stringified := nqp::if(
            nqp::index((my $color-str := $.ansi-color), ","),
            colored($!char, $color-str),
            nqp::if(
                nqp::chars(my $clr := %color-cache{$color-str} //= color($color-str)),
                nqp::join("", nqp::list($clr, $!char, $reset-color)),
                $!char
            )
        );
    }

    method ansi-color is raw {
        my $cl := nqp::list();
        nqp::stmts(
            nqp::if($!fg, nqp::push($cl, nqp::decont($!fg))),
            nqp::if($!bg, nqp::push($cl, "on_$!bg")),
        );
        nqp::join(" ", $cl)
    }

    multi method FROM(::?CLASS:D: |c) { self.WHAT.FROM(|c) }

    multi method FROM(::?CLASS:U: Str:D $str where *.chars == 0 | 1, *%c) {
        Cell.new: :char($str), |%c
    }

    multi method FROM(::?CLASS:U: Any:U, *%c) { Cell.new: |%c }

    multi method FROM(::?CLASS:U: Cell:D $cell, *%c) {
        $cell.clone: |%c;
    }

    method Str { $!stringified // self!stringify }
}

has Int:D $.w is required;
has Int:D $.h is required;
has @.cells;
has Str:D $.term-profile = 'ansi'; # or 'universal'
has Bool $.is-unicode = so %*ENV<TERM> ~~ /:i utf/;
has &.cursor-sub;

# Viewport
has Rect $!viewport is mooish(:lazy, :clearer);

has $!inv-rects;

submethod TWEAK(*%c) {
    self.setup: |%c;
}

method !build-viewport {
    self.viewport: 0, 0, $!w, $!h;
}

method setup( :@cells ) {
    @!cells = [ [ Nil xx $!w ] xx $!h ];
    $!vw //= $!w;
    $!vh //= $!h;
    if @cells {
        for @cells[ ^min( $!h, +@cells ) ].kv -> $i, @row {
            my $w = $!w min +@row;
            @!cells[$i].splice( 0, $w, @row[^$w]);
        }
    }
    &!cursor-sub = move-cursor-template($!term-profile);
    $!inv-rects := nqp::list();
}

method new-from-self(::?CLASS:D: *%args) {
    self.WHAT.new:
            :$!w, :$!h, :$!vx, :$!vy, :$!vw, :$!vh,
            :$!term-profile, :$!is-unicode, |%args;
}

method clone(::?CLASS:D: *%args) {
    self.WHAT.new:
            :$!w, :$!h, :$!vx, :$!vy, :$!vw, :$!vh,
            :$!term-profile, :$!is-unicode, :@!cells,
            |%args;
}

method clear {
    @!cells = [];
}

#| Returns string which would output a cell at given position.
# Argument positions are related to viewport. I.e. if $!vy==2 and $y==1 then we take cell from @!cells 3rd row and
# output it at screen position 1. If cell at the given position is not set then only cursor movement to the next x
# coordinate will be generated. Same if coords are out of the viewport.
method cell-string(UInt:D $x, UInt:D $y) {
    return '' if $x > $!vw || $y > $!vh;
    nqp::stmts(
        (my $cl := nqp::list()),
        nqp::if(
            (my $c := @!cells[$y + $!vy; $x + $!vx]),
            nqp::stmts(
                nqp::push($cl, &!cursor-sub($x, $y)),
                nqp::push($cl, ~$c)
            ),
            nqp::if(
                $x + 1 > $!vw,
                nqp::push($cl, ''),
                nqp::push($cl, &!cursor-sub($x + 1, $y)),
            )
        ),
        nqp::join("", $cl)
    )
}

multi method set-cell(UInt:D $x where * < $!w, UInt:D $y where * < $!h, Str:D $char where *.chars == 1) {
    @!cells[$y; $x] = $char;
}

multi method set-cell(UInt:D $x where * < $!w, UInt:D $y where * < $!h, Cell:D $c) {
    @!cells[$y; $x] = $c
}

multi method set-cell(UInt:D $x where * < $!w, UInt:D $y where * < $!h, *%c) {
    @!cells[$y; $x] = Cell.new: |%c;
}

proto method imprint(UInt:D $x where * < $!w, UInt:D $y where * < $!h, |) {*}
multi method imprint(UInt:D $x where * < $!w, UInt:D $y where * < $!h, Str:D $line, :$fg? is copy, :$bg? is copy) {
    my @chars = $line.comb[^(min $!w, $line.chars)];
    # A color can be a triplet of color channels.
    $fg = .join(",") with $fg;
    $bg = .join(",") with $bg;
    my $use-Cell = $fg || $bg;
    for @chars.kv -> $i, $char {
        my $cx = $x + $i;
        next unless $.is-paintable($cx, $y);
        # Condition branches must be the same as set-cell method bodies. Avoiding extra method call for perofrmance.
        if $use-Cell {
            @!cells[$y; $cx] = Cell.new: :$char, :$fg, :$bg;
        }
        else {
            @!cells[$y; $cx] = $char;
        }
    }
}

multi method imprint(UInt:D $x where * < $!w, UInt:D $y where * < $!h, UInt:D $w where * > 0, UInt:D $h where * > 0, Str :$fg? is copy, Str :$bg? is copy) {
    for $y..^(min $!h, $y + $h) -> $row {
        my @row := @!cells[$row];
        for $x..^(min $!w, $x + $w) -> $col {
            next unless $.is-paintable($col, $row);
            my $c = Cell.FROM( @row[$col], :$fg, :$bg );
            @row[$col] = Cell.FROM( @row[$col], :$fg, :$bg );
        }
    }
}

multi method imprint(UInt:D $x where * < $!w, UInt:D $y where * < $!h, Str:D $line, Bool :$text-only! where *) {
    my @row = @!cells[$y];
    my @chars = $line.comb;
    for ^(min $!w - $x, +@chars) -> $i {
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

#| With four parameters viewport is been set.
multi method viewport(UInt:D $x, UInt:D $y, Int:D $w where * > 0, Int:D $h where * > 0 --> Nil) {
    $.throw: X::Canvas::BadViewport, :$x, :$y, :$w, :$h unless self.contains($x, $y, $w, $h);
    $!viewport = Vikna::Rect.new: :$x, :$y, :$w, :$h;
}

multi method viewport(Vikna::Rect:D $rect) {
    $.throw: X::Canvas::BadViewport, :$rect unless self.contains($rect);
    $!viewport = $rect.clone;
}

#| Return array of cells
multi method viewport {
    my @viewport[$!vh; $!vw];
    for ^$!vh -> $vrow {
        my @row = @!cells[$!vy + $vrow];
        my @vrow = @viewport[$vrow];
        for ^$!vw -> $vcol {
            my \cell = @row[$!vx + $vcol];
            @vrow[$vcol] = cell ~~ Cell ?? Cell.clone !! cell;
        }
    }
    @viewport
}

#| Returns a string viable for sending to the console. Anchors to the position at $x, $y
multi method viewport(UInt:D $x, UInt:D $y) {
    my $viewport := nqp::list();
    for ^$!vh -> $vrow {
        my @row := @!cells[$!vy + $vrow];
        # Move cursor once per line.
        nqp::push($viewport, nqp::decont(&!cursor-sub($x, $y + $vrow)));
        my $last-color = '';
        for ^$!vw -> $vcol {
            my \cell = @row[$!vx + $vcol];
            my $color = '';
            nqp::if(
                nqp::istype(nqp::decont(cell), Cell),
                nqp::stmts(
                    ($color = cell.ansi-color),
                    nqp::if(
                        ( $color ne $last-color ), # Do we need to change color?
                        nqp::stmts(
                            nqp::push($viewport, nqp::decont( $Cell::reset-color) ),
                            nqp::if( $color, nqp::push( $viewport, color($color) ) ),
                        )
                    ),
                    nqp::push($viewport, nqp::decont(nqp::defor(cell.char, '')))
                ),
                nqp::stmts(
                    nqp::if( nqp::chars($last-color), nqp::push($viewport, nqp::decont($Cell::reset-color)) ),
                    nqp::push($viewport, nqp::decont(nqp::defor(cell, '')))
                )
            );
            $last-color = nqp::defor($color, '');
        }
    }
    # my @v = $viewport;
    # note @v.perl;
    nqp::join("", $viewport);
}

multi method invalidate(::?CLASS:D:) {
    $.invalidate(0, 0, $!w, $!h)
}
multi method invalidate(::?CLASS:D: Vikna::Rect:D $rect) {
    $.add-inv-rect($rect) unless $.is-paintable($rect);
}
multi method invalidate(+@rect where *.elems == 4) {
    $.add-inv-rect(@rect)
        unless $.is-paintable(@rect);
}

method invalidate-reset {
    $!inv-rects := nqp::list();
}

multi method is-paintable(::?CLASS:D: Vikna::Point:D $p ) { self.is-paintable: $p.x, $p.y }
multi method is-paintable(::?CLASS:D: UInt:D $x, UInt:D $y --> Bool) {
    # By default the whole canvas is non-paintable unless invalidated rects are added.
    return False unless    $x < $!w
                        && $y < $!h
                        && nqp::elems($!inv-rects);
    my \iter = nqp::iterator($!inv-rects);
    my $unpaintable := 1;
    nqp::while(
        nqp::if($unpaintable, iter),
        nqp::stmts(
            nqp::shift(iter),
            ( $unpaintable := !nqp::iterval(iter).contains($x, $y) ),
        )
    );
    !$unpaintable
}

#| See if the whole rectange is inside another invalidated rectangle.
multi method is-paintable(+@rect where *.elems == 4) { $.is-paintable( Vikna::Rect.new: |@rect ) }
multi method is-paintable(::?CLASS:D: Vikna::Rect:D $rect) {
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

# multi method add-inv-rect(UInt:D $x, UInt:D $y, UInt:D $w where * > 0, UInt:D $h where * > 0) {
#     nqp::push( $!inv-rects, Vikna::Rect.new: $x, $y, $w, $h );
# }

multi method add-inv-rect(+@rect where *.elems == 4) {
    nqp::push( $!inv-rects, Vikna::Rect.new: |@rect );
}

multi method add-inv-rect(Vikna::Rect:D $r) {
    nqp::push( $!inv-rects, $r );
}

method invalidates {
    nqp::hllize($!inv-rects)
}

method FALLBACK($name, |c) {
    die "FALLBACL($name): ", c.perl;
}
