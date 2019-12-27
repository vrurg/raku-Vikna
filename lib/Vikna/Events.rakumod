use v6.e.PREVIEW;
unit package Vikna;

use Vikna::Rect;
use Vikna::Point;
use AttrX::Mooish;

role Event {
    has $.origin is mooish(:lazy);  # Originating object.
    has $.dispatcher is required;   # Dispatching object. Changes on re-dispatch.
    has Bool:D $.cleared = False;

    method clear {
        $!cleared = True;
    }

    method last {
        require ::(Vikna::Events);
        ::('Vikna::Events::CX::Event::Last').new(:ev(self)).throw
    }

    method build-origin { $!dispatcher }
}

role Event::Control does Event is export { }

class Event::SyncQueue does Event::Control is export {
    has Promise:D $.promise .= new;
}

# Marks events not eligible for holding
role Event::Unholdable { }

role Event::TitleChange does Event::Control is export {
    has $.old-title;
    has $.title;
}

role Event::ColorChange does Event::Control is export {
    has $.old-fg;
    has $.old-bg;
    has $.fg;
    has $.bg;
}

role Event::Geomish does Event::Control is export {
    has Vikna::Rect:D $.from is required;
    has Vikna::Rect:D $.to is required;
}

role Event::Positional does Event::Control is export {
    has Vikna::Point:D $.from is required;
    has Vikna::Point:D $.to is required;
}

class Event::RedrawRequest does Event::Control is export {
    # has @.invalidations is required;
}

class Event::Geom does Event::Geomish is export { }

class Event::ScreenGeom does Event::Geomish is export { }

class Event::Resize does Event::Geomish is export { }

class Event::Move does Event::Geomish is export { }

class Event::Clear does Event::Control is export { }

class Event::ScrollPosition does Event::Positional is export { }

role Event::Kbd does Event is export { }

class Event::KeyPressed does Event::Kbd is export { }

role Event::ReParent does Event::Control is export {
    has $.parent;
}

class Event::Attach does Event::ReParent { }
class Event::Detach does Event::ReParent { }

role Event::Holdish does Event {
    has Event:U $ev-type;
    submethod TWEAK(:$!ev-type) {
    }
}
class Event::HoldAcquire does Event::Holdish does Event::Unholdable { }
class Event::HoldRelease does Event::Holdish does Event::Unholdable { }
