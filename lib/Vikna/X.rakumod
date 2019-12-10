use v6;
unit package Vikna;
use Vikna::Rect;
use Vikna::Point;

class X::Base is Exception is export {
    has $.obj is required;

    method message {
        "[{$!obj.WHICH}]"
    }
}

role X::Geometry is export {
    has Vikna::Rect $.rect handles <Str>;

    multi method new(*@pos where * == 4, *%c) {
        self.new(rect => Vikna::Rect.new: |@pos, |%c)
    }
    multi method new(|) { nextsame }
}

class X::Canvas::BadViewport is X::Base does X::Geometry is export {
    method message {
        callsame() ~ " Bad viewport position, possibly out of range: " ~ self.X::Geometry::Str
    }
}
