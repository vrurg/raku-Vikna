use v6.e.PREVIEW;
# Screen driver
use Vikna::Object;
use Vikna::EventEmitter;

unit role Vikna::Screen;
also is Vikna::Object;
also does Vikna::EventEmitter;

use Vikna::Point;
use Vikna::Rect;
use AttrX::Mooish;
use Vikna::Events;
use Vikna::Color;
use Vikna::Canvas;
use Vikna::Color::RGB;

has Vikna::Rect $.geom is mooish(:lazy, :clearer, :predicate);
has Bool $.is-unicode is mooish(:lazy, :clearer);

method build-is-unicode { ... }
method build-geom       { ... }

method init { ... }
method shutdown { ... }

# Color mapping routines. Map into what current screen understands.
proto method color(|) {*}
multi method color(Str:D $name)                     { ... }
multi method color(UInt:D $r, UInt:D $g, UInt:D $b, UInt:D $a = 255) { ... }
# multi method color(@chan)                           { ... }
multi method color(*%chan)                          { ... }
multi method color(Vikna::Color:D)                  { ... }
multi method color(Any:U)                           { Vikna::Color::RGB }

multi method print(::?CLASS:D: Vikna::Point:D $pos, Vikna::Canvas:D $viewport, *%c ) { self.print: $pos.x, $pos.y, $viewport, |%c }
multi method print(::?CLASS:D: Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, *%c ) { ... }

method screen-resize {
    my $from = $!geom;
    $.clear-geom;
    $.post-event: Event::ScreenGeom, :$from, to => $!geom;
}
