use v6.e.PREVIEW;

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
use Vikna::Color;
use Vikna::Utils;
use Vikna::CAttr;

class Cell {
    has Str $.char where { !.defined || .chars == 0 | 1 };
    has Vikna::CAttr:D $.attr is required handles<fg bg style>;

    method Str { $!char.raku }
}

has Vikna::Rect:D $.geom is required handles <x y w h>;
has Mu $!paintable-mask;
has Bool $!paintable-expired = True;

# nqp::list() of 3 planes, each plane is nqp::list() of rows, each row is nqp::list() of elems.
# Planes:
#   0 - characters
#   1 - fg color
#   2 - bg color
#   3 - style
# Style is a char. Meaning see in Vikna::Utils
my constant PLANE-COUNT = 4;
has Mu $!planes;

# Viewport
has Vikna::Rect $!vp-geom is mooish(:lazy, :clearer);

has $.inv-mark-color;
has $!inv-rects;

multi method new(Dimension $w, Dimension $h, *%c) {
    self.new: geom => Vikna::Rect.new(:0x, :0y, :$w, :$h), |%c
}

multi method new(Dimension :$w, Dimension :$h, *%c) {
    self.new: geom => Vikna::Rect.new(:0x, :0y, :$w, :$h), |%c
}

submethod TWEAK(*%c) {
    $!inv-rects := nqp::list();
    self!setup-planes(|%c);
}

method clone {
    my $cloned = callsame;
    my $p-idx = -1;
    my $planes := nqp::list();
    nqp::while(
        (++$p-idx < PLANE-COUNT),
        nqp::stmts(
            (my $src-plane := nqp::atpos($!planes, $p-idx)),
            (my $plane := nqp::list()),
            (my $iter := nqp::iterator($src-plane)),
            nqp::while(
                $iter,
                nqp::stmts(
                    nqp::shift($iter),
                    nqp::push($plane, nqp::clone(nqp::iterval($iter)))
                )
            ),
            nqp::push($planes, $plane)
        )
    );
    nqp::bindattr(nqp::decont($cloned), Vikna::Canvas, '$!planes', $planes);
    $cloned
}

method !setup-planes(:$from?, :$viewport?) {
    my ($w, $h) = $.w, $.h;
   self.trace: "Setting up canvas planes from ", $from.WHICH;
    my ($from-x, $from-y, $from-w, $from-h, $from-planes);
    my ($copy-w, $copy-h);
    if $from {
        if $viewport {
            $from-x := $from.vx;
            $from-y := $from.vy;
            $from-w := $from.vw;
            $from-h := $from.vh;
        }
        else {
            $from-x := $from-y := 0;
            $from-w := $from.w;
            $from-h := $from.h;
        }
        $copy-w = $w min $from-w;
        $copy-h = $h min $from-h;
        $from-planes := nqp::clone(nqp::getattr(nqp::decont($from), ::?CLASS, '$!planes'));
    }
    my $p-idx = -1;
    $!planes := nqp::list();
    nqp::while(
        (++$p-idx < PLANE-COUNT),
        nqp::stmts(
            (my $plane := nqp::list()),
            (my $from-plane := nqp::if($from, nqp::atpos($from-planes, $p-idx), Nil)),
            nqp::push($!planes, $plane),
            (my $y = -1),
            nqp::while(
                (++$y < $h),
                nqp::stmts(
                    (my $row := nqp::list()),
                    (my $from-row := nqp::if($from, nqp::atpos($from-plane, ($from-y + $y)), Nil)),
                    nqp::push($plane, $row),
                    (my $x = -1),
                    nqp::while(
                        (++$x < $w),
                        nqp::stmts(
                            (my $sym := ''),
                            nqp::if(
                                $from-row,
                                nqp::if(
                                    nqp::if(($x < $copy-w), ($y < $copy-h)),
                                    ($sym := nqp::atpos($from-row, ($from-x + $x)))
                                )
                            ),
                            (nqp::push($row, $sym))
                        )
                    )
                )
            )
        )
    )
}

method !build-vp-geom {
    $!geom.clone
}

method new-from-self(::?CLASS:D: *%args) {
    self.create: self.WHAT, geom => $!geom.clone, vp-geom => $!vp-geom.clone, |%args;
}

method dup(::?CLASS:D: *%args) {
    self.create: self.WHAT, geom => $!geom.clone, vp-geom => $!vp-geom.clone, :from(self), |%args;
}

method clear {
    self!setup-planes;
}

proto method imprint(UInt:D $x, UInt:D $y, |) {
    {*}
}

# a string
multi method imprint($x, $y, Str:D() $line, Vikna::CAttr:D $attr, Int :$span?) {
    self.imprint($x, $y, $line, |$attr.Profile, :$span)
}
multi method imprint($x, $y, Str:D() $line, :$fg? is copy, :$bg? is copy, :$style? is copy, Int :$span?)
{
    return if $y >= $.h || $x >= $.w;
    self!build-paintable-mask;
    $fg    = $fg.join(",") if $fg ~~ Positional:D;
    $bg    = $bg.join(",") if $bg ~~ Positional:D;
    $style = to-style-char($style);
    nqp::stmts(
        (my $char-count := $line.chars),
        (my $len := min ($.w - $x), ($span // $char-count)),
        (my $chars := nqp::split('', nqp::substr($line, 0, $len))),
        nqp::if(nqp::istype($fg, Positional:D), ($fg := $fg.join(","))),
        nqp::if(nqp::istype($bg, Positional:D), ($bg := $bg.join(","))),
        (my $crow := nqp::atpos(nqp::atpos($!planes, 0), $y)),
        (my $fgrow := nqp::atpos(nqp::atpos($!planes, 1), $y)),
        (my $bgrow := nqp::atpos(nqp::atpos($!planes, 2), $y)),
        (my $strow := nqp::atpos(nqp::atpos($!planes, 3), $y)),
        (my $prow := nqp::atpos($!paintable-mask, $y)),
        (my $i = -1),
        nqp::while(
            (++$i < $len),
            nqp::stmts(
                (my $cx := $x + $i),
                nqp::if(
                    nqp::if(nqp::isge_i($cx, 0), nqp::atpos_i($prow, $cx)), # $cx >= 0 && printable
                    nqp::stmts(
                        nqp::if($i < $char-count, nqp::bindpos($crow, $cx, nqp::atpos($chars, $i))),
                        nqp::if($fg, nqp::bindpos($fgrow, $cx, $fg)),
                        nqp::if($bg, nqp::bindpos($bgrow, $cx, $bg)),
                        nqp::if($style, nqp::bindpos($strow, $cx, $style))
                    )
                )
            )
        )
    )
}

# fill a rect with color
multi method imprint($x, $y, $w, $h, Vikna::CAttr:D $attr) {
    self.imprint($x, $y, $w, $h, |$attr.Profile)
}
multi method imprint($x, $y, $w, $h, :$fg? is copy, :$bg? is copy, :$style? is copy) {
    self!build-paintable-mask;
    $fg    = $fg.join(",") if $fg ~~ Positional:D;
    $bg    = $bg.join(",") if $bg ~~ Positional:D;
    $style = to-style-char($style);
    nqp::stmts(
        (my $cw := min $x + $w, $.w),
        (my $ch := min $y + $h, $.h),
        (my $cy = ($y max 0) - 1),
        (my $fgplane := nqp::atpos($!planes, 1)),
        (my $bgplane := nqp::atpos($!planes, 2)),
        (my $stplane := nqp::atpos($!planes, 3)),
        nqp::while(
            (++$cy < $ch),
            nqp::stmts(
                (my $fgrow := nqp::atpos($fgplane, $cy)),
                (my $bgrow := nqp::atpos($bgplane, $cy)),
                (my $strow := nqp::atpos($stplane, $cy)),
                (my $prow := nqp::atpos($!paintable-mask, $cy)),
                (my $cx = ($x max 0) - 1),
                nqp::while(
                    (++$cx < $cw),
                    nqp::if(
                        nqp::atpos_i($prow, $cx),
                        nqp::stmts(
                            nqp::if($fg,    nqp::bindpos($fgrow, $cx, $fg)),
                            nqp::if($bg,    nqp::bindpos($bgrow, $cx, $bg)),
                            nqp::if($style, nqp::bindpos($strow, $cx, $style)),
                        )
                    )
                ),
            )
        )
    );
}

# Copy from another canvas
multi method imprint($x, $y, ::?CLASS:D $from, :$skip-empty = True) {
    self!build-paintable-mask;
    my $no-skip := nqp::not_i($skip-empty);
    nqp::stmts(
        (my $from-planes := nqp::getattr(nqp::decont($from), ::?CLASS, '$!planes')),
        (my $from-cplane := nqp::atpos($from-planes, 0)),
        (my $from-fgplane := nqp::atpos($from-planes, 1)),
        (my $from-bgplane := nqp::atpos($from-planes, 2)),
        (my $from-stplane := nqp::atpos($from-planes, 3)),
        (my $cplane := nqp::atpos($!planes, 0)),
        (my $fgplane := nqp::atpos($!planes, 1)),
        (my $bgplane := nqp::atpos($!planes, 2)),
        (my $stplane := nqp::atpos($!planes, 3)),
        (my $from-w := $from.w),
        (my $w := $.w),
        (my $from-y = $from.h),
        nqp::if($from-y > (my $hh := $.h - $y), ($from-y = $hh)),
        nqp::while(
            (--$from-y >= 0),
            nqp::stmts(
                (my $to-y := $y + $from-y),
                (my $from-crow := nqp::atpos($from-cplane, $from-y)),
                (my $from-fgrow := nqp::atpos($from-fgplane, $from-y)),
                (my $from-bgrow := nqp::atpos($from-bgplane, $from-y)),
                (my $from-strow := nqp::atpos($from-stplane, $from-y)),
                (my $crow := nqp::atpos($cplane, $to-y)),
                (my $fgrow := nqp::atpos($fgplane, $to-y)),
                (my $bgrow := nqp::atpos($bgplane, $to-y)),
                (my $strow := nqp::atpos($stplane, $to-y)),
                (my $prow := nqp::atpos($!paintable-mask, $to-y)),
                (my $from-x = $from-w),
                nqp::if($from-x > (my $ww := $w - $x), ($from-x = $ww)),
                nqp::while(
                    (--$from-x >= 0),
                    nqp::stmts(
                        (my $to-x := $x + $from-x),
                        nqp::if(
                            nqp::atpos_i($prow, $to-x), # is paintable
                            nqp::stmts(
                                nqp::if(
                                    nqp::unless((my $from-char := nqp::atpos($from-crow, $from-x)), $no-skip),
                                    nqp::bindpos($crow, $to-x, $from-char)),
                                nqp::if(
                                    nqp::unless((my $from-fg := nqp::atpos($from-fgrow, $from-x)), $no-skip),
                                    nqp::bindpos($fgrow, $to-x, $from-fg)),
                                nqp::if(
                                    nqp::unless((my $from-bg := nqp::atpos($from-bgrow, $from-x)), $no-skip),
                                    nqp::bindpos($bgrow, $to-x, $from-bg)),
                                nqp::if(
                                    nqp::unless((my $from-st := nqp::atpos($from-strow, $from-x)), $no-skip),
                                    nqp::bindpos($strow, $to-x, $from-st)),
                            )
                        )
                    )
                )
            )
        )
    )
}

method pick($x is copy, $y is copy, :$viewport?) {
    if $viewport {
        return Nil if $x < $.vx || $x >= ($.vx + $.vw) || $y < $.vy || $y >= ($.vy + $.vh);
        $x += $.vx;
        $y += $.vy;
    }
    else {
        return Nil if $x < 0 || $x >= $.w || $y < 0 || $y >= $.h;
    }
    nqp::stmts(
        (my $cplane := nqp::atpos($!planes, 0)),
        (my $fgplane := nqp::atpos($!planes, 1)),
        (my $bgplane := nqp::atpos($!planes, 2)),
        (my $stplane := nqp::atpos($!planes, 3)),
        Cell.new(
            char => nqp::atpos(nqp::atpos($cplane, $y), $x),
            attr => cattr(
                fg    => nqp::atpos(nqp::atpos($fgplane, $y), $x),
                bg    => nqp::atpos(nqp::atpos($bgplane, $y), $x),
                style => nqp::atpos(nqp::atpos($stplane, $y), $x),
            )
        )
    )
}

method get-planes(\cplane, \fgplane, \bgplane, \stplane) {
    cplane = nqp::atpos($!planes, 0);
    fgplane = nqp::atpos($!planes, 1);
    bgplane = nqp::atpos($!planes, 2);
    stplane = nqp::atpos($!planes, 3);
}

#| With four parameters viewport is been set.
multi method viewport(UInt:D $x, UInt:D $y, Int:D $w where * > 0, Int:D $h where * > 0 --> Nil) {
    self.throw: X::Canvas::BadViewport, :$x, :$y, :$w, :$h unless $!geom.contains($x, $y, $w, $h);
    $!vp-geom = self.create: Vikna::Rect, :$x, :$y, :$w, :$h;
}

multi method viewport(Vikna::Rect:D $rect) {
    self.throw: X::Canvas::BadViewport, :$rect unless $!geom.contains($rect);
    $!vp-geom = $rect.clone;
}

multi method viewport(--> Vikna::Canvas:D) {
    return self if $!vp-geom == $!geom;
    self.new: geom => $!vp-geom, :from(self), :viewport;
}

multi method invalidate(::?CLASS:D:) {
    $.invalidate(0, 0, $.w, $.h)
}
multi method invalidate(::?CLASS:D: Vikna::Rect:D $rect) {
    $.add-inv-rect($rect) unless $.is-paintable-rect($rect);
}
multi method invalidate(+@rect where *.elems == 4) {
    my $r := self.create: Vikna::Rect, @rect;
    self.add-inv-rect: $r unless self.is-paintable-rect: $r;
}

method is-paintable(::?CLASS:D: $x, $y) {
    # By default the whole canvas is non-paintable unless invalidated rects are added.
    my $w := $.w;
    return False unless    nqp::isle_i($x, $w)
                        && nqp::isle_i($y, $.h)
                        && nqp::elems($!inv-rects);
    self!build-paintable-mask if $!paintable-expired;
    nqp::atpos_i(nqp::atpos($!paintable-mask, $y), $x)
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
    return unless $!paintable-expired;
    $!paintable-mask := nqp::list();
    my $y = -1;
    my $h = $.h;
    my $w = $.w;
    nqp::while(
        (++$y < $h),
        nqp::stmts(
            (my $x = -1),
            (my $row := nqp::list_i()),
            (my $bgrow := nqp::atpos(nqp::atpos($!planes, 2), $y)),
            nqp::push($!paintable-mask, $row),
            nqp::while(
                (++$x < $w),
                nqp::stmts(
                    (my $i = nqp::elems($!inv-rects)),
                    (my $paintable := 0),
                    nqp::while(
                        nqp::if((--$i >= 0), !$paintable),
                        nqp::stmts(
                            (my \inv-rect := nqp::atpos($!inv-rects, $i)),
                            ($paintable := nqp::istrue(inv-rect.contains($x, $y)))
                        )
                    ),
                    (nqp::bindpos_i($row, $x, $paintable)),
                    nqp::if($!inv-mark-color,
                        nqp::if($paintable,
                            nqp::bindpos($bgrow, $x, $!inv-mark-color),
                            nqp::bindpos($bgrow, $x, 'black')
                        )
                    ),
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
    nqp::push( $!inv-rects, Vikna::Rect.new: |@rect );
    $!paintable-expired = True;
}

multi method add-inv-rect(Vikna::Rect:D $r) {
    nqp::push( $!inv-rects, $r );
    $!paintable-expired = True;
}

method clear-inv-rects {
    $!inv-rects := nqp::list()
}

method invalidations {
    nqp::hllize($!inv-rects)
}

multi method fill(Str:D $char where *.chars == 1, BasicColor :$fg?, BasicColor :$bg?, :$style?) {
    my $line = $char x $.w;
    for ^$.h -> $row {
        $.imprint(0, $row, $line, :$fg, :$bg, :$style);
    }
}

method vx { $!vp-geom.x }
method vy { $!vp-geom.y }
method vw { $!vp-geom.w }
method vh { $!vp-geom.h }

multi method Str(::?CLASS:D) {
    "{self.^name}|{self.^id}[{$.w}x{$.h}]"
}
