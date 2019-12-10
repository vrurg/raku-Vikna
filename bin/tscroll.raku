use v6.d;
use lib "%*ENV<HOME>/src/Raku/Terminal-Print/lib";
use lib "%*ENV<HOME>/src/Raku/raku-Terminal-Window/lib";
use Vikna::App;
use Vikna::TextScroll;

class MyApp is Vikna::App {
    method main {
        my $ts = $.desktop.create-child: Vikna::TextScroll, :w(80), :h(30), :x(20), :y(3), :auto-clear;
        $ts.ev.subscribe: -> $ev {
            if $ev ~~ Event::BufChange {
                self.desktop.redraw
            }
        };
        for ^1000 {
            my $c = 10.rand.Int;
            my $s = $c x $c;
            $ts.say: "Line {.fmt: '%4d'} of {$ts.buffer.elems.fmt: '%4d'} $s";
            # sleep .01;
        }
        $ts.print: "Line A\c[FORM FEED]Line B";
        sleep 1;
        $ts.print: "\rLB";
        sleep 1;
    }
}

MyApp.run;
