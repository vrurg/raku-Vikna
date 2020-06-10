use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Point> - geometric point type

=SYNOPSIS

my $p1 = Vikna::Point(13, 42);
my $p2 = Vikna::Point(1, 1);
my $p3 = $p1 + $p2;

=DESCRIPTION

Implements basic point operations required by the framework.

Does L<C<Vikna::Coord>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Coord.md>.

=METHODS

=head2 C<multi new(Int:D $x, Int:D $y, *%c)>

Shortcut to C<Vikna::Point.new(:$x, :$y)> way of creating a new point object.

Also, C<Vikna::Point(...args...)> is equivalent to C<Vikna::Point.new(...args...)>.

=head2 C<multi relative-to(Int:D $x, Int:D $y)>
=head2 C<multi relative-to(Vikna::Coord:D $point)>

Returns a new point object which represents a difference between C<self> and the coordinates in the argument(s).

Consider it a vector subtraction.

=head2 C<multi aboslute(Int:D $x, Int:D $y)>
=head2 C<multi absolute(Vikna::Coord:D $point)>

Given that C<self> represents a relative point, creates a new point object which represent position of C<self> in the
coordinate system to which argument(s) belong.

Consider it a vector addition.

=head2 C<Str>

Returns a string representation of the point.

=head2 C<gist>

Same as C<Str>

=OPERATORS

=head2 C<infix:<+>>, C<infix:<->>

Vector addition and subtraction of two points.

=head1 SEE ALSO

L<Vikna|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md>,
L<Vikna::Manual|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>,
L<Vikna::Coord|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Coord.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

use Vikna::Coord;
# Immutable class
unit class Vikna::Point;
also does Vikna::Coord;

multi method new(Int:D $x, Int:D $y, *%c) {
    self.new(:$x, :$y, |%c)
}

method list { $!x, $!y }
method pairs { :$!x, :$!y }

proto method relative-to(::?CLASS:D: |) {*}
multi method relative-to(Int:D $x, Int:D $y --> Vikna::Point:D) {
    self.new: $!x - $x, $!y - $y
}
multi method relative-to(Vikna::Coord:D $point --> Vikna::Point:D) {
    self.new: $!x - .x, $!y - .y with $point
}
multi method relative-to($rect) {
    self.reltaive-to: .x, .y given $rect
}

proto method aboslute(::?CLASS:D: |) {*}
multi method absolute(Vikna::Coord:D $point --> Vikna::Point:D) {
    self.new: $!x + .x, $!y + .y with $point
}
multi method aboslute(Int:D $x, Int:D $y) {
    self.new: $!x + $x, $!y + $y
}

method Str {
    "\{x:$!x, y:$!y}"
}

method gist {
    self.Str
}

multi infix:<+>(::?CLASS:D $a, ::?CLASS:D $b) is export {
    $a.WHAT.new: :x($a.x + $b.x), :y($a.y + $b.y);
}

multi infix:<->(::?CLASS:D $a, ::?CLASS:D $b) is export {
    $a.WHAT.new: :x($a.x - $b.x), :y($a.y - $b.y);
}

method CALL-ME(|c) {
    self.new: |c
}
