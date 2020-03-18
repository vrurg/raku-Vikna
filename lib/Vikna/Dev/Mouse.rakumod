use v6.e.PREVIEW;

unit module Vikna::Dev::Mouse;
use Vikna::Events;

role EventProcessor {
    has @!last-event;
    has @!last-time;
    has @!last-click-time;
    has @!button-state = False xx 6;
    has $.click-timeout = .2;
    has $.double-click-timeout = .3;
    method translate-mouse-event(Event::Mouse \evType, *%p) {
        my @events = [evType];
        my $now = now;
        my $button = %p<button> // 0;
        my $last-event = @!last-event[$button];
        if evType ~~ Event::Mouse::Press | Event::Mouse::Release {
            @!button-state[$button] = evType ~~ Event::Mouse::Press;
        }
        if evType ~~ Event::Mouse::Release && $last-event ~~ Event::Mouse::Press {
            if ($now - @!last-time[$button]) <= $!click-timeout {
                @events.push: Event::Mouse::Click;
                my $lct = @!last-click-time[$button];
                if $lct && ($now - $lct) < $!double-click-timeout {
                    @events.push: Event::Mouse::DoubleClick;
                }
                @!last-click-time[$button] = $now;
            }
        }
        @!last-event[$button] := evType;
        @!last-time[$button] = $now;
        @events
            ?? @events.map: { \($_, buttons => @!button-state, |%p) }
            !! ()
    }
}
