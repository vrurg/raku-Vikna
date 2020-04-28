use v6.e.PREVIEW;
use Test::Async;
use Vikna::App;
use Vikna::Test::OS;

unit class Vikna::Test::App;

also is Vikna::App;

has $.test-suite;

method build-os {
    $.create: Vikna::Test::OS;
}

method build-tracer-name { "TestApp" }

# method run(|) {
#     $!test-suite = test-suite;
# }

method self-diagnostics {
    $.test-suite.subtest: "Test App Self Diagnostics" => {
        # isa-ok $.os, Vikna::Test::OS, "OS initialized as Vikna::Test::OS";
        # isa-ok $.screen, Vikna::Test::Screen, "the screen initialized as Vikna::Test::Screen";
        # isa-ok $.desktop, Vikna::Desktop, "desktop initialized as Vikna::Desktop";
        # my @evs = nqp::getattr(nqp::decont($.desktop), Vikna::Widget, '@!event-source');
        # ok ?(@evs.grep: * ~~ Vikna::Screen), "a screen is in the list of desktop event sources";
    }
}
