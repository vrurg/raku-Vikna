use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Widget::GroupMember;
also is Vikna::Widget;

use Vikna::Events;

has Vikna::Widget:D $.group is required;

# We don't do own event queue. Everything is managed by the Group widget we belong to.
method start-event-handling { }

proto method route-event(::?CLASS:D: Event:D, *%) {*}
multi method route-event(Event:D $ev where Event::Spreadable | Event::Positionish, *%c) {
    self.trace: "Group member dispatch of definite ", $ev;
    if $ev.dispatcher === self {
        self.Vikna::Widget::route-event: $ev, |%c
    }
    else {
        # Comes from an external source, proceed via group dispatch.
        $.group.dispatch: $ev,
    }
}
multi method route-event(Event:D $ev, *%c) {
    self.trace: "GROUP MEMBER {self.name} DISPATCH [$ev] VIA {$.group.name}";
    $.group.re-dispatch: $ev, |%c
}

### Command senders ###

method redraw {
    $.group.redraw;
}

proto method send-command(Event::Command $, |) {*}
multi method send-command(Event::Command:U \evType, |args) {
    self.trace: "Group member send command (args) ", evType.^name;
    $.group.send-command: evType, args, %(origin => self, dispatcher => self)
}
multi method send-command(Event::Command:U \evType, Capture:D $args) {
    self.trace: "Group member send command (capture) ", evType.^name;
    $.group.send-command: evType, $args, %(origin => self, dispatcher => self)
}

### Utility methods ###

method detach {
    with $.parent {
        .remove-member: self;
    }
    else {
        self.throw: X::Detach::NoParent;
    }
}
