use v6.e.PREVIEW;
unit role Vikna::Elevatable;

use Vikna::Events;

has Bool:D $.bypass-elevatish is rw = False;

method maybe-to-top {...}

multi method route-event(::?CLASS:D: Event::Pointer::Elevatish:D $ev) {
    $.trace: "Elevatish event ", $ev, :event;
    # Nothing to do if event has been processed or already on top
    if $ev.cleared || ($.parent && $.parent.is-topmost(self)) {
        nextsame
    }
    $.maybe-to-top;
}
