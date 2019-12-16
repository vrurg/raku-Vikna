use v6.e.PREVIEW;
# Immutable class
unit class Vikna::Point;

has Int:D $.x is required;
has Int:D $.y is required;

multi method new(Int:D $x, Int:D $y, *%c) {
    self.new(:$x, :$y, |%c)
}

multi method new(*%c) { nextsame }

multi method Array { [$!x, $!y] }

multi method List { $!x, $!y }

multi infix:<+>(::?CLASS:D $a, ::?CLASS:D $b) is export {
    $a.WHAT.new: :x($a.x + $b.x), :y($a.y + $b.y);
}

method CALL-ME(Int:D $x, Int:D $y) {
    self.new: :$x, :$y
}
