use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Widget::GroupMember;
also is Vikna::Widget;

use Vikna::Events;

has Vikna::Widget:D $.group is required;

# We don't do own event queue. Everything is managed by the Group widget we belong to.
method start-event-handling { }

proto method dispatch(|) {*}
# multi method dispatch(::?CLASS:D: Event::Command:D $ev, |c) {
#     # note self.name, " COMMAND ", $ev.^shortname, " DISPATCH DIRECTLY";
#     self.send-event: $ev
# }
multi method dispatch(::?CLASS:D: Event:U \event, |c) {
    self.Vikna::Widget::dispatch: event, |c
}
multi method dispatch(::?CLASS:D: Event:D $ev, |c) {
    $.trace: "GROUP MEMBER {self.name} DISPATCH [$ev] VIA {$.group.name}";
    $.group.re-dispatch: $ev, |c
}

### Command senders ###

method redraw {
    $.group.redraw;
}

### Utility methods ###

method detach {
    with $.parent {
        .remove-member: self;
    }
    else {
        $.throw: X::Detach::NoParent;
    }
}
