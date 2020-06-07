use v6.e.PREVIEW;

use Test::Async <Base Vikna::Test>;
use Vikna::Events;
use Vikna::Test::App;
use Vikna::Utils;
use Vikna::Rect;

plan 3;

class MyDesktop
    is Vikna::Desktop
{
    my @bg-chars = <+ * .>;
    multi method event(Event::Screen::Geom:D $ev) {
        my $chr = @bg-chars.shift;
        self.cmd-setbgpattern: $chr;
        @bg-chars.push: $chr;
        nextsame;
    }
}

class MyApp is Vikna::Test::App {
    method build-desktop {
        self.test-init: self.create: MyDesktop, |%.desktop-profile, :geom($.screen.geom.clone);
    }

    method test-init($desktop) {
        my $test-suite = test-suite;

        my sub init-event($ev, $task) {
            my $screen = $.screen;
            await subtest "initial state" => {
                is $ev.id, 0, "the first init event id is 0";
                is-rect-filled $screen.buffer, $screen.geom, "screen is empty",
                    :char(""), :fg(""), :bg(""), :style(VSTransparent);
            }
        }

        my sub post-redraw($ev, $task) {
            my $screen = $.screen;
            my $desktop = $.desktop;
            await subtest "filled screen" => {
                is-rect-filled $screen.buffer, $screen.geom, "screen is filled by desktop",
                    :char($desktop.bg-pattern), :fg($desktop.fg), :bg($desktop.bg), :style($desktop.style);
            }
        }

        my sub start-resize($passed, $task) {
            # Only try resizing if the initial sequnce passed
            if $passed {
                self.test-resize: $test-suite;
            }
            else {
                $.desktop.quit;
            }
        }

        is-event-sequence $desktop, [
            %(
                type => Event::Init,
                checker => &init-event,
                #                accept => -> $ev { diag "accepting $ev"; True },
                #                checker => -> $ev { diag "checker $ev"; True },
                #                orig => $desktop,
                #                disp => $desktop,
                message => "desktop init",
            ),
            %(
                type => Event::Cmd::Redraw,
                message => "first redraw",
            ),
            %(
                type => Event::Flattened,
                message => "first canvas flattening",
            ),
            %(
                type => Vikna::Event::Updated,
                message => "submitted to the screen",
            ),
            %(
                type => Event::Screen::Ready,
                checker => &post-redraw,
                message => "screen updated with desktop",
                on-status => &start-resize,
            )
        ], "Desktop init sequence", :async, :timeout(30),
#            :trace-events,
            :defaults{ on-status => -> $passed, $ { $.desktop.quit unless $passed } };

        $desktop
    }

    method test-resize($test-suite) {
        my $dest-rect = Vikna::Rect(80, 25);

        my sub check-geoms($ev, $) {
            await subtest "geoms changed" => {
                is $ev.to, $dest-rect, "event 'to' geometry is correct";
                is $.screen.geom, $dest-rect, "screen geometry changed";
                is $.desktop.geom, $dest-rect, "desktop geometry matches that of the screen";
            }
        }

        my sub desktop-geom-change($ev, $) {
            $ev.geom == $dest-rect
        }

        my sub post-sgc-redraw($ev, $) {
            is-rect-filled $.screen.buffer, $dest-rect, "screen redrawn",
                :attr($.desktop.attr),
                :char<+> # Pattern char is rotated on each resize by MyDesktop event method. This is the first resize.
        }

        $test-suite.is-event-sequence: $.desktop, [
            %(
                type => Event::Screen::Geom,
                message => "screen geom notification",
                checker => &check-geoms,
            ),
            %(
                type => Event::Changed::Geom,
                message => 'desktop geometry changed',
                checker => &desktop-geom-change,
            ),
            %(
                type => Event::Updated,
                message => "desktop redrawn",
                checker => &post-sgc-redraw, # post-screen-geom-change-redraw
                # We're done, quit
                on-status => -> | { $.desktop.quit },
            ),
        ], "Screen resized", :async, :timeout(30),
#            :trace-events,
            :defaults{
                on-status => -> $passed, $ { $.desktop.quit unless $passed }
            };

        $.screen.test-geom = $dest-rect;
    }

    method main(|) {
        self.self-diagnostics;
#        $.desktop.quit;
    }
}

# MyApp.new.run;
given MyApp.new(:!debugging) {
    .run
}

done-testing;