use v6.e.PREVIEW;
use Test::Async <Base Vikna::Test>;
use Vikna::Events;
use Vikna::Test::App;
use Vikna::Utils;
use Vikna::Widget;
use Vikna::Rect;

class MyWidget is Vikna::Widget {
    submethod TWEAK(|) {
        self.test-startup;
        self.test-move;
    }

    method !is-drawn($ev, $task) {
        my $screen = $.app.screen.buffer;
        my $desktop = $.app.desktop;
        my $dgeom = $desktop.geom;
        my $dattr = $desktop.attr;
        is-rect-filled $screen, $.geom, "widget is on the desktop", :attr($.attr);
        is-rect-filled $screen, Vikna::Rect(0, 0, $dgeom.w, $.y), "desktop above the widget", :attr($dattr);
        is-rect-filled $screen, Vikna::Rect(0, $.geom.bottom + 1, $dgeom.w, $dgeom.h - $.geom.bottom),
            "desktop below the widget", :attr($dattr);
        is-rect-filled $screen, Vikna::Rect(0, $.y, $.x, $.h), "desktop left to the widget", :attr($dattr);
        is-rect-filled $screen, Vikna::Rect($.geom.right + 1, $.y, $dgeom.w - $.geom.right, $.h),
            "desktop right to the widget", :attr($dattr);
    }

    method test-startup {
        is-event-sequence $.app.desktop,
            [
                evs-task( Event, :skip-until('widget ready'), ),
                evs-task(
                    Event::Screen::Ready,
                    "desktop drawn on the screen",
                    :skip-until('widget redrawn'),
                    :checker( -> |c { self!is-drawn(|c) } ),
                    :on-status( -> $passed, $ {
                        evs-syncer('move widget').signal($passed);
                        self.set-geom(42,12,15,10);
                    } ),
                ),
            ],
            "desktop with widget to screen",
            :async,
            :timeout(30),
#            :trace-events,
            :defaults{ :quit-on-flunk };

        is-event-sequence self,
            [
                evs-task( Event::Init, "initialized",
                    :on-status( -> $passed, $ { evs-syncer('widget ready').signal($passed); } )),
                evs-task( Vikna::Event::Flattened, "widget redrawn and canvas flattened",
                    on-status => -> $passed, $, {
                        evs-syncer('widget redrawn').signal($passed);
                    },
                ),
                evs-task( Event::Updated, "widget imprinted on desktop" )
            ],
            "Widget startup",
            :async,
            :timeout(20),
#            :trace-events,
            :defaults{ :quit-on-flunk };
    }

    method test-move {
        is-event-sequence $.app.desktop,
            [
#                evs-task(Event, "awaiting for widget change", :skip-until('widget post-geom')),
                evs-task(Event::Screen::Ready, "desktop content after widget change",
                    :skip-until('widget post-geom'),
                    :checker( -> |c { self!is-drawn(|c) } ),
                    :on-status( -> $passed, $ { $.app.desktop.quit } )),
            ],
            "desktop on widget move",
            :async,
#            :trace-events,
            :defaults{ :quit-on-flunk };

        is-event-sequence self,
            [
                evs-task( Event::Changed::Geom, "wait for geom",
                    :skip-until('widget set geom command'),
                    :checker( -> $ev, $ { $ev.to == Vikna::Rect(42,12,15,10) } ),
                          ),
            ],
            "Change geometry notification",
            :async,
            :defaults{ :quit-on-flunk };

        is-event-sequence self,
            [
                evs-task( Event::Cmd::SetGeom, "set geometry command event",
                    :skip-until('move widget'),
                    :on-status( -> $passed, $ {
                        $.app.desktop.flatten-block;
                        evs-syncer('widget set geom command').signal($passed);
                    } )),
#                evs-task( Event::Cmd::Redraw, "post-geom change redraw" ),
                evs-task( Event::Flattened, "widget submitted to parent",
                    :on-status( -> $passed, $ {
                        evs-syncer('widget post-geom').signal($passed);
                        $.app.desktop.flatten-unblock;
                    } )),
                evs-task( Event::Updated, "widget submitted to parent" ),
            ],
            "Change geometry",
#            :trace-events,
            :async,
            :defaults{ :quit-on-flunk };
    }
}

class MyApp is Vikna::Test::App {
    method main(|) {
        $.desktop.create-child: MyWidget, :x(10), :y(5), :w(20), :h(5), :attr{
            :pattern<❄︎>, :fg<yellow>, :bg<blue>, :style(VSNone),
        };
    }
}

plan 5;
given MyApp.new(:!debugging) {
    .run
}

done-testing;
