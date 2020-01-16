use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Widget::Group;
also is Vikna::Widget;

use Vikna::Events;

### Command handlers ###

### Utility methods ###
# Typically, group doesn't draw itself. Even the background.
method draw(|) { }

method event-for-children(Event:D $ev) {
    $.for-children: {
        .event($ev.clone)
    }
}
