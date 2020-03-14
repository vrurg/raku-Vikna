use v6.e.PREVIEW;

unit module Vikna::Dev::Mouse;
use Vikna::Events;

role EventProcessor {
    has $!last-event;
    has $!last-time;
    has $!last-click-time;
    has $.click-timeout = .2;
    has $.double-click-timeout = .3;
    method translate-mouse-event(Event::Mouse:D $ev) {
        my @events;
        my $now = now;
        with $!last-event {
            if $ev ~~ Event::Mouse::Release && $!last-event ~~ Event::Mouse::Press {
                if ($now - $!last-time) <= $!click-timeout {
                    @events.push: Event::Mouse::Click.new-from($ev);
                    if $!last-click-time && ($now - $!last-click-time) < $!double-click-timeout {
                        @events.push: Event::Mouse::DoubleClick.new-from($ev);
                    }
                    $!last-click-time = $now;
                }
            }
        }
        $!last-event = $ev.clone;
        $!last-time = $now;
        @events
    }
}
