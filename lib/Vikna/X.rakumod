use v6.e.PREVIEW;
unit module Vikna;
use Vikna::Rect;
use Vikna::Point;
use Vikna::Events;

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

class X::BadColor is X::Base is export {
    has $.color;

    method message {
        "Bad color: " ~ $!color
    }
}

role X::Eventish is X::Base is export {
    has Vikna::Event $.ev is required;
}

class X::Event::ReParent does X::Eventish {
    method message {
        "Re-parent event received which doesn't belong to me"
    }
}

role X::Widget is X::Base { }

class X::Widget::ExtraUnlock {
    has Int:D $.count is required;
    method message { "Too many unlocks: {$.count} too many" }
}

class X::Event::Unsubscribe {
    has $.obj is required;
    method message {
        "Can't unsubscribe from " ~ $!obj.^name ~ " object: not subscribed to"
    }
}

class X::Event::LostRedraw does X::Eventish {
    method message {
        "Lost redraw command produced by " ~ $.ev.^name;
    }
}

class X::Event::Stopped does X::Eventish {
    method message {
        "Can't send " ~ $.ev.^name ~ ": event handling is stopped"
    }
}

class CX::Event::Last is export {
    has Vikna::Event:D $.ev is required;
}
