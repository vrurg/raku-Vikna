use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Widget::GroupMember;
also is Vikna::Widget;

use Vikna::Events;

has Vikna::Widget:D $.group is required;

# We don't do own event queue. Everything is managed by the Group widget we belong to.
method start-event-handling { }

proto method dispatch(|) {*}
multi method dispatch(Event::Command \event, |c) {
    self.Vikna::Widget::dispatch: event, |c;
}
multi method dispatch(Event \event, |c) {
    $.group.dispatch: event, |c;
}
