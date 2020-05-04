use v6.e.PREVIEW;

use Test;
use Vikna::Test;
use Vikna::Test::App;
use Vikna::Desktop;
use Vikna::Events;

plan 4;

class MyDesktop is Vikna::Desktop {
    has $!drawn = False;
    has $!test-first-draw = True;
    method draw {
        callsame;
        pass "Drawn for the first time" unless $!drawn;
        $!drawn = True;
    }

    multi method event(Event::Screen::Ready:D $ev) {
        if $!test-first-draw && $!drawn {
            pass "Printed to the screen";
            my $screen = $.app.screen;
            test-rect-fill
                $screen.buffer,
                $.app.screen.geom,
                "desktop filled the screen",
                :char($.app.desktop.attr.pattern);
            $.app.desktop.quit;
        }
        nextsame;
    }
}

class MyTestApp is Vikna::Test::App {
    method build-desktop {
        self.create: MyDesktop, |%.desktop-profile, :geom($.screen.geom.clone);
    }
    method main(|) {
        $.self-diagnostics;
    }
}

my MyTestApp:D $app .= new;
$app.run;

done-testing;
