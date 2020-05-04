use v6.e.PREVIEW;

# use Vikna::Test::EventSequencer;
use Test::Async <Base Vikna::Test>;
use Vikna::Events;
use Vikna::Test::App;

class MyDesktop
    is Vikna::Desktop
{
    multi method event(Event::Init:D $ev) {

        my sub first-focus($ev, $task) {
            test-suite.pass: "FIRST FOCUS";
        }

        is-event-sequence self, [
            type => Event::Focus::In,
            %(
                type => Event::Cmd::Redraw,
#                accept => -> $ev { diag "accepting $ev"; True },
#                checker => -> $ev { diag "checker $ev"; True },
                on-match => &first-focus,
#                orig => $desktop,
#                disp => $desktop,
                message => "desktop first redraw",
            ),
            %(
                type => Event::Mouse::Move,
                on-match => -> $ev, $rec --> Nil { diag "UPDATED"; },
                message => "updated after redraw",
#                on-status => -> $pass, $task --> Nil { diag "STATUS: $pass"; self.quit },
                timeout => 5,
            )
        ], "Desktop init sequence", :async, :timeout(10);
    }
}

class MyApp is Vikna::Test::App {
    method build-desktop {
        self.create: MyDesktop, |%.desktop-profile, :geom($.screen.geom.clone);
    }
    method main(|) {
        self.self-diagnostics;
        $.desktop.quit;
    }
}

# MyApp.new.run;
given MyApp.new(:debugging) {
    my $desktop = .desktop;
    .run
}
