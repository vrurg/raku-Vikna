use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Rect> - the rectangle type

=SYNOPSIS

=begin code
my $rect = Vikna::Rect(10, 5, 42, 13);
my $rect2 = $rect.move-by(-5, 5);       # 5, 10, 42, 13
$rect.contains($rect2);                 # False
=end code

=DESCRIPTION

Does L<C<Vikna::Coord>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Coord.md>.

Represents a rectangle object.

=ATTRIBUTES

=head3 C<UInt:D $.w>, C<UInt:D $.h>

Width and height of the rectangle, respectively.

=head3 C<Int $.right>, C<Int $.bottom>

Right and bottom widget boundaries.

=METHODS

=head3 C<new($x, $y, $w, $h)>

A shortcut to C<new(:$x, :$y, :$w, :$h)>. The class also supports a callable for of instantiation, as shown in
L<#SYNPOSIS>.

=head3 C<dup(*%twiddles)>

Duplicates a rectangle instance using C<new>.

=head3 C<Array()>

Coerces a rectangle into an array of it's coordinates and dimensions.

=head3 C<List()>

Similar to C<Array> method above, but coerce into a C<List>.

=head3 C<coords()>

An alias to C<List> method.

=head3 C<multi overlap($x, $y, $w, $h)>
=head3 C<multi overlap(Vikna::Rect:D $rec)>

Returns I<True> if two rectangles overlap.

=head3 C<multi clip(Vikna::Rect:D $into, :$copy?)>
=head3 C<multi clip(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h)>

Clip a rectangle by C<$into>.

=head3 C<multi dissect(Vikna::Rect:D $by)>
=head3 C<multi dissect(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h)>

Dissect a rectangle with C<$by>. It means that C<$by> is cut out of the rectangle we dissect and the remaining area is
dissected into sub-rectangles.

=head3 C<multi dissect(@by)>

Dissect by a list of rectangles.

=head3 C<multi contains(Int:D $x, Int:D $y)>
=head3 C<multi contains(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h)>
=head3 C<multi contains(Vikna::Coord:D $point)>
=head3 C<multi contains(Vikna::Rect:D $rect)>

Returns I<True> is the argument is contained by rectangle.

=head3 C<multi relative-to(Int:D $x, Int:D $y)>
=head3 C<multi relative-to(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h, :$clip = False)>
=head3 C<multi relative-to(Vikna::Coord:D $point)>
=head3 C<multi relative-to(Vikna::Rect:D $rect, :$clip = False)>

Takes current rectangle and returns a new one which coordinates are relative to coordinates of C<$rect>. With C<:clip>
clips the new rectangle by C<$rect>.

=head3 C<multi absolute(Int:D $x, Int:D $y)>
=head3 C<multi absolute(Vikna::Rect:D $rec, :$clip = False)>

Assuming that rectangle coordinates are relative to the argument, transforms them into the "absolute" values and returns
a new rectangle. With C<:clip> it is cliped by C<$rect>.

=head3 C<multi move(Int:D $x, Int:D $y)>
=head3 C<multi move(Vikna::Coord:D $point)>

Returns a new rectangle with it's origin set to the argument.

=head3 C<multi move-by(Int:D $dx, Int:D $dy)>
=head3 C<multi move-by(Vikna::Coord:D $delta)>

Returns a new rectangle shifted by the argument.

=head3 C<Str()>
=head3 C<gist()>

Strigify rectangle.

=OPERATORS

=head3 C<infix:<+>(Vikna::Rect:D $r, Vikna::Coord:D $delta)>

Same as C<move-by>.

=head3 C<infix:<==>(Vikna::Rect:D $a, Vikna::Rect:D $b)>

Returns I<True> if both rectangles have same origins and dimensions.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md>,
L<C<Vikna::Classes>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Classes.md>,
L<C<Vikna::Coord>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Coord.md>,
L<C<Vikna::Point>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Point.md>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

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

proto method overlap(::?CLASS:D: |) {*}
multi method overlap(::?CLASS:D: ::?CLASS:D $r) { self.overlap: .x, .y, .w, .h with $r }
multi method overlap(::?CLASS:D: Int:D $x, Int:D $y, UInt:D $w, UInt:D $h) {
    my $right = $x + $w - 1;
    my $bottom = $y + $h - 1;
    return nqp::not_i(
        nqp::unless(
            nqp::isgt_i( $!x, $right ),
            nqp::unless(
                nqp::islt_i( $!right, $x ),
                nqp::unless(
                    nqp::islt_i( $!bottom, $y ),
                    nqp::isgt_i( $!y, $bottom )
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

proto method clip(::?CLASS:D: |) {*}
multi method clip(::?CLASS:D: ::?CLASS:D $into, :$copy! where ?*) { self.clone.clip: .x, .y, .w, .h with $into }
multi method clip(::?CLASS:D: ::?CLASS:D $into) { self.clip: .x, .y, .w, .h with $into }
multi method clip(::?CLASS:D: Int:D $x, Int:D $y, UInt:D $w, UInt:D $h) {
    if self.overlap($x, $y, $w, $h) {
        my $right = $x + $w - 1;
        my $bottom = $y + $h - 1;
        self.new: |clip-coords([$!x, $!y, $!right, $!bottom], [$x, $y, $right, $bottom]);
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
multi method contains(Int:D $x, Int:D $y, UInt:D $w, UInt:D $h) {
    $.contains($x, $y) and $.contains($x + $w - 1, $y + $h - 1)
}
multi method contains(Vikna::Rect:D $rect) {
    $.contains(.x, .y) and $.contains(.right, .bottom) given $rect
}

#Assuming that the argument is defined in the same coordinate system as ours returns a new rectangle which coordinates
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
multi method relative-to(Vikna::Coord:D $point) {
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
multi method move(Vikna::Coord:D $point) {
    self.new: :x(.x), :y(.y), :$!w, :$!h with $point
}
multi method move(Int:D $x, Int:D $y) {
    self.new: :$x, :$y, :$!w, :$!h
}

proto method move-by(::?CLASS:D: |) {*}
multi method move-by(Vikna::Coord:D $dp) {
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

multi infix:<+>(::?CLASS:D $r, Vikna::Coord:D $delta) is export {
    $r.move-by: $delta
}

multi infix:<==>(Vikna::Rect:D $a, Vikna::Rect:D $b) is export {
    $a.x == $b.x && $a.y == $b.y && $a.w == $b.w && $a.h == $b.h
}

