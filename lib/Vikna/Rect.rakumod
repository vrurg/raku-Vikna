use v6;
unit class Vikna::Rect;

use nqp;
use Vikna::Point;

has Int:D $.x is required;
has Int:D $.y is required;
has UInt:D $.w is required;
has UInt:D $.h is required;
has Int $.right;
has Int $.bottom;

multi method new(::?CLASS:U: +@r where *.elems == 4, *%c) {
    $.new: |%( <x y w h> Z=> @r ), |%c
}

multi method new(*@p where *.elems != 0 | 4) {
    die ::?CLASS.^name ~ " only takes named or 4 positional parameters, got "
        ~ @p.elems ~ " positionals instead"
}

submethod TWEAK {
    $!right = $!x + $!w - 1;
    $!bottom = $!y + $!h - 1;
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

multi method clip(::?CLASS:D: +@into where *.elems == 4, :$copy?) { $.clip( ::?CLASS.new: @into, :$copy ) }
multi method clip(::?CLASS:D: ::?CLASS:D $into, :$copy! where ?*) { $.clone.clip: $into }
multi method clip(::?CLASS:D: ::?CLASS:D $into) {
    if $.overlap($into) {
        $!x max= $into.x;
        $!y max= $into.y;
        $!right min= $into.right;
        $!bottom min= $into.bottom;
        $!w = $!right - $!x + 1;
        $!h = $!bottom - $!y + 1;
    }
    else {
        $!x = $!y = $!w = $!h = $!right = $!bottom = 0;
    }
    self
}

multi method dissect(::?CLASS:D: +@by) { $.dissect( ::?CLASS.new: @by ) }
multi method dissect(::?CLASS:D: ::?CLASS:D $by) {
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

multi method contains(::?CLASS:D: Vikna::Point:D $p) { $.contains: $p.x, $p.y }
multi method contains(::?CLASS:D: Int:D $px, Int:D $py) {
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
multi method contains(::?CLASS:D Vikna::Rect:D $r) { $.contains: $r.x, $r.y, $r.w, $r.h }
multi method contains(::?CLASS:D Int:D $x, Int:D $y, Int:D $w, Int:D $h) {
    nqp::if( self.contains($x, $y), self.contains($x + $w - 1, $y + $h - 1) )
}

#| Assuming that the argument is defined in the same coordinates as ours returns a new rectangle which coordinates are
#relative to the argument. If :clip is defined then the resulting rectange would also be clipped to fit the argument.
multi method relative-to(::?CLASS:D: ::?CLASS:D $rect, :$clip? --> Vikna::Rect:D) {
    self.relative-to: $rect.x, $rect.y, $rect.w, $rect.h, :$clip
}
multi method relative-to(::?CLASS:D: Int:D $x, Int:D $y, UInt:D $w, UInt:D $h, Bool :$clip = False) {
    my $r = Vikna::Rect.new: $!x - $x, $!y - $y, $!w, $!h;
    $r.clip(0, 0, $w, $h) if $clip;
    $r
}

multi method move(::?CLASS:D: Vikna::Point:D $point) { $!x = $p.x; $!y = $p.y }
multi method move(::?CLASS:D: Int:D $x, Int:D $y) { $!x = $x; $!y = $y }

multi method move-by(::?CLASS:D: Vikna::Point:D $dp) { $!x += $dp.x; $!y += $dp.y }
multi method move-by(::?CLASS:D: Int:D $dx, Int:D $dy) { $!x += $dx; $!y += $dy }

method Str {
    "x:$!x, y:$!y, w:$!w, h:$!h"
}
