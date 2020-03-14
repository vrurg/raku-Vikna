use v6.e.PREVIEW;
use Vikna::Coord;
# Immutable class
unit class Vikna::Point;
also does Vikna::Coord;

multi method new(Int:D $x, Int:D $y, *%c) {
    self.new(:$x, :$y, |%c)
}

multi method new(*%c) { nextsame }

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

method CALL-ME(|c) {
    self.new: |c
}
