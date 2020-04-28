use v6.e.PREVIEW;

use Vikna::Test::App;
# use Vikna::Test;
use Vikna::Events;
# use Test::Async;

# class MyDesktop is Vikna::Desktop does Vikna::Test::EventSequencer {
#     has $!screen-geom-event;
#     multi method event(Event::Init:D) {
#         note "INITING";
#         given self.is-event-sequence: [
#                 %(
#                     type => Event::Cmd::Redraw,
#                     accept => -> $ev { note "accepting $ev"; True },
#                     checker => -> $ev { note "checker $ev"; True },
#                     callback => -> $ev, $rec --> Nil { note "callback on $ev for ‘{$rec.message}’"; },
#                     orig => self,
#                     disp => self,
#                     message => "desktop first redraw",
#                 ),
#                 %(
#                     type => Event::Mouse::Move,
#                     callback => -> $ev, $rec --> Nil { note "UPDATED"; },
#                     message => "updated after redraw",
#                 )
#             ],
#             "Desktop init sequence"
#         {
#             .then: { note "SEQ TEST COMPLETE WITH ", .result; $.quit };
#         }
#         note "INITIALIZED";
#         nextsame;
#     }
# }

class MyApp is Vikna::Test::App {
    # method build-desktop {
    #     self.create: MyDesktop, |%.desktop-profile, :geom($.screen.geom.clone);
    # }
    method main(|) {
    }
}

# given MyApp.new(:!debugging) {
#     sequence-events .desktop, [], "Desktop init sequence";
# }
