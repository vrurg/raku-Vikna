use v6.e.PREVIEW;

unit class Vikna::Test::Screen;

use Vikna::Rect;
use Vikna::Canvas;
use Vikna::Screen;
use AttrX::Mooish;
use Test;

also does Vikna::Screen;

has Bool:D $.simulate-unicode = True;
has Vikna::Rect:D $.test-geom is rw is mooish(:filter, :trigger) .= new: 0, 0, 80, 24;
has Int:D $test-color-depth = 24;

has Vikna::Canvas $.buffer is mooish(:lazy, :clearer) handles <pick>;
has Vikna::Point:D $.pointer-pos .= new: 0, 0;
has Bool:D $.pointer-visible = True;

method build-is-unicode { $!simulate-unicode }

method build-geom {
    self.clear-buffer;
    $!test-geom
}

method !build-buffer {
    my $buf = Vikna::Canvas.new: $.geom.w, $.geom.h;
    $buf.invalidate;
    $buf
}

method build-color-depth {
    $!test-color-depth
}

method filter-test-geom($new-size is copy, :$constructor?, *%c) {
    if $new-size ~~ Positional && $new-size.elems == 4 {
        $new-size = Vikna::Rect.new: |$new-size;
    }
    $new-size
}

method trigger-test-geom(*@, :$constructor, *%) {
    unless $constructor {
        self.screen-resize;
    }
}

submethod profile-default {
    simulate-unicode    => True,
    test-geom           => Vikna::Rect.new(0, 0, 120, 45),
    test-color-depth    => 24,
}

submethod profile-checkin(%profile, %, %, %) {
    unless %profile<test-geom> ~~ Vikna::Rect:D {
        %profile<test-geom> = Vikna::Rect.new: |%profile<test-geom>;
    }
}

# multi method color( Str:D $name ) { $name }
# multi method color(UInt:D $r, UInt:D $g, UInt:D $b, UInt:D $a = 255) {
#     Vikna::Color::RGB.new: :$r, :$g, :$b, :$a
# }
# multi method color(*%chan) {
#     Vikna::Color::RGB.new: |%chan
# }
# multi method color(Vikna::Color:D $c) {
#     $c.clone
# }

proto method screen-print(Int:D, Int:D, |) {*}

multi method screen-print(Int:D $x, Int:D $y, Vikna::Canvas:D $canvas) {
    $!buffer.imprint: $x, $y, $canvas;
}

multi method screen-print(Int:D $x, Int:D $y, Str:D $str, *%c) {
    $!buffer.imprint: $x, $y, $str, |%c;
}

multi method move-cursor(UInt:D $x, UInt:D $y) {
    $!pointer-pos .= new($x, $y);
}

method hide-cursor { $!pointer-visible = False }
method show-cursor { $!pointer-visible = True }

method init {
}

### Test methods ###
