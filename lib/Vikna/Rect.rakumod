use v6.e.PREVIEW;
use Vikna::Coord;
# Immutable class
unit class Vikna::Rect;
also does Vikna::Coord;

use nqp;
use Vikna::Point;
use Vikna::Utils;

has UInt:D $.w is required;
has UInt:D $.h is required;
has Int $.right;
has Int $.bottom;

multi method new(::?CLASS: +@r where *.elems == 4, *%c) {
    self.new: |%( <x y w h> Z=> @r ), |%c
}

multi method new(::?CLASS: +@r where *.elems == 2, *%c) {
    self.new: |%( <w h> Z=> @r ), |%c
}

multi method new(*@p where *.elems != 0 | 2 | 4) {
    die ::?CLASS.^name ~ " only takes all named, or 2, or 4 positional parameters, got "
        ~ @p.elems ~ " positionals instead"
}

submethod TWEAK {
    $!right = $!x + $!w - 1;
    $!bottom = $!y + $!h - 1;
}

method dup(*%c) {
    self.new: :$!x, :$!y, :$!w, :$!h, |%c;
}

method Array(::?CLASS:D:) {
    [$!x, $!y, $!w, $!h]
}

method List(::?CLASS:D:) {
    $!x, $!y, $!w, $!h
}

method coords(::?CLASS:D: --> List) {
    $!x, $!y, $!right, $!bottom
}

multi method overlap(::?CLASS:D: +@r where *.elems == 4) { $.overlap( ::?CLASS.new: @r ) }
multi method overlap(::?CLASS:D: ::?CLASS:D $r) {
    return nqp::not_i(
        nqp::unless(
             nqp::isgt_i( $!x, $r.right ),
             nqp::unless(
                nqp::islt_i( $!right, $r.x ),
                nqp::unless(
                    nqp::islt_i( $!bottom, $r.y ),
                    nqp::isgt_i( $!y, $r.bottom )
                )
             )
        )
    )
}

# Input rect arrays: [x, y, right, bottom]
# Returns: [x, y, w, h]
my sub clip-coords(@r is copy, @into) {
    @r[$_] = (@r[$_] max @into[$_]) min (@into[$_+2] + 1) for 0..1;
    @r[$_] = ((@r[$_] min @into[$_]) max (@r[$_ - 2] - 1)) - @r[$_ - 2] + 1 for 2..3;
    @r
}

multi method clip(::?CLASS:D: +@into where *.elems == 4, :$copy) { $.clip( ::?CLASS.new: @into, :$copy ) }
multi method clip(::?CLASS:D: ::?CLASS:D $into, :$copy! where ?*) { $.clone.clip: $into }
multi method clip(::?CLASS:D: ::?CLASS:D $into) {
    if $.overlap($into) {
        self.new: |clip-coords([$!x, $!y, $!right, $!bottom], [.x, .y, .right, .bottom]) with $into;
    }
    else {
        self.new: :0x, :0y, :0w, :0h
    }
}

proto method dissect(::?CLASS:D: |) {*}
multi method dissect(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h) { $.dissect( ::?CLASS.new: :$x, :$y, :$w, :$h ) }
multi method dissect(::?CLASS:D $by) {
    return (self,) unless $.overlap($by);
    my ($rxl, $ryt, $rxr, $ryb) = ($!x, $!y, $!right, $!bottom);
    my ($bxl, $byt, $bxr, $byb) = ($by.x, $by.y, $by.right, $by.bottom);
    # Rect is fully covered
    return () if $rxl >= $bxl && $rxr <= $bxr && $ryt >= $byt && $ryb <= $byb;

    my $dissects := nqp::list();
    nqp::stmts(
        nqp::if(
            nqp::islt_i( $rxl, $bxl ), # Left cut-off
            nqp::stmts(
                nqp::push( $dissects, ::?CLASS.new( $rxl, $ryt, $bxl - $rxl, $ryb - $ryt + 1 ) ),
                ( $rxl := $bxl )
            )
        ),
        nqp::if(
            nqp::isgt_i( $rxr, $bxr ), # Right cut-off
            nqp::stmts(
                nqp::push( $dissects, ::?CLASS.new( $bxr + 1, $ryt, $rxr - $bxr, $ryb - $ryt + 1 ) ),
                ( $rxr := $bxr )
            )
        ),
        nqp::if(
            nqp::islt_i( $ryt, $byt ), # Top cut-off
            nqp::push( $dissects, ::?CLASS.new( $rxl, $ryt, $rxr - $rxl + 1, $byt - $ryt ) ),
        ),
        nqp::if(
            nqp::isgt_i( $ryb, $byb ), # Bottom cut-off
            nqp::push( $dissects, ::?CLASS.new( $rxl, $byb + 1, $rxr - $rxl + 1, $ryb - $byb ) ),
        ),
    );
    nqp::hllize($dissects)
}

multi method dissect(@by) {
    my $dissects := nqp::list(self<>);
    for @by -> $by {
        nqp::stmts(
            (my $sub-ds := nqp::list()),
            nqp::while(
                nqp::elems($dissects),
                nqp::stmts(
                    (my $r := nqp::shift($dissects)),
                    (nqp::push($sub-ds, $_<>) for $r.dissect($by))
                )
            ),
            ($dissects := $sub-ds)
        );
        last unless nqp::elems($dissects)
    }
    nqp::hllize($dissects);
}

proto method contains(::?CLASS:D: |) {*}
multi method contains(Int:D $px, Int:D $py) {
    nqp::if(
        nqp::isge_i($px, $!x),
        nqp::if(
            nqp::isge_i($py, $!y),
            nqp::if(
                nqp::isle_i($px, $!right),
                nqp::isle_i($py, $!bottom)
            )
        )
    )
}
multi method contains(Vikna::Coord:D $point) {
    self.contains: .x, .y with $point
}
multi method contains(Int:D $x, Int:D $y, Int:D $w, Int:D $h) {
    $.contains($x, $y) and $.contains($x + $w - 1, $y + $h - 1)
}
multi method contains(Vikna::Rect:D $rect) {
    $.contains(.x, .y) and $.contains(.right, .bottom) given $rect
}

#| Assuming that the argument is defined in the same coordinate system as ours returns a new rectangle which coordinates
#are relative to the argument. If :clip is defined then the resulting rectange would also be clipped to fit the
#argument.
proto method relative-to(::?CLASS:D: |) {*}
multi method relative-to(::?CLASS:D $rect, Bool :$clip? --> Vikna::Rect:D) {
    self.relative-to: $rect.x, $rect.y, $rect.w, $rect.h, :$clip
}

multi method relative-to(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h, Bool :$clip = False) {
    if $clip {
        # clip-coords([$!x, $!y, $!right, $!bottom], [$x, $y, $x + $w - 1, $y + $h - 1]);
        self.new: |clip-coords(
                    [$!x - $x, $!y - $y, $!right - $x, $!bottom - $y],
                    [0, 0, $w - 1, $h - 1])
    }
    else {
        self.new: $!x - $x, $!y - $y, $!w, $!h
    }
}
multi method relative-to(Int:D $x, Int:D $y) {
    self.new: $!x - $x, $!y - $y, $!w, $!h
}
multi method relative-to(Vikna::Point:D $point) {
    self.new: $!x - .x, $!y - .y, $!w, $!h with $point
}

proto method absolute(::?CLASS:D: |) {*}
multi method absolute(::?CLASS:D $rect, Bool:D :$clip = False --> Vikna::Rect:D) {
    if $clip {
        my ($rx, $ry, $rr, $rb) = $rect.x, $rect.y, $rect.right, $rect.bottom;
        self.new: |clip-coords(
            [$!x + $rx, $!y + $ry, $!right + $rx, $!bottom + $ry],
            [$rx, $ry, $rr, $rb])
    }
    else {
        self.absolute: $rect.x, $rect.y
    }
}
multi method absolute(Int:D $x, Int:D $y --> Vikna::Rect:D) {
    self.new: $!x + $x, $!y + $y, $!w, $!h
}

proto method move(::?CLASS:D: |) {*}
multi method move(Vikna::Point:D $point) {
    self.new: :x(.x), :y(.y), :$!w, :$!h with $point
}
multi method move(Int:D $x, Int:D $y) {
    self.new: :$x, :$y, :$!w, :$!h
}

proto method move-by(::?CLASS:D: |) {*}
multi method move-by(Vikna::Point:D $dp) {
    self.new: :x($!x + .x), :y($!y + .y), :$!w, :$!h with $dp
}
multi method move-by(Int:D $dx, Int:D $dy) {
    self.new: :x($!x += $dx), :y($!y += $dy), :$!w, :$!h
}

method Str {
    "\{x:$!x, y:$!y, w:$!w, h:$!h\}"
}

method gist {
    self.Str
}

method CALL-ME(*@pos) { ::?CLASS.new: |@pos }

multi infix:<+>(::?CLASS:D $r, Vikna::Point:D $delta) is export {
    $r.move-by: $delta
}

multi infix:<==>(Vikna::Rect:D $a, Vikna::Rect:D $b) is export {
    $a.x == $b.x && $a.y == $b.y && $a.w == $b.w && $a.h == $b.h
}

