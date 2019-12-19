use v6.d;
use lib "%*ENV<HOME>/src/Raku/Terminal-Print/lib";
use lib "%*ENV<HOME>/src/Raku/raku-Terminal-Window/lib";
use Vikna::App;
use Vikna::TextScroll;

my ($st, $et);
my $count = 100;

class ScrollApp is Vikna::App {
    method main {
        my $ts = $.desktop.create-child: Vikna::TextScroll, :w(80), :h(30), :x(20), :y(3); #, :auto-clear;
        $.desktop.invalidate;
        # $ts.evevents.subscribe: -> $ev {
        #     if $ev ~~ Event::BufChange {
        #         self.desktop.redraw
        #     }
        # };
        $st = now;
        for ^$count {
            my $c = 10.rand.Int;
            my $s = $c x $c;
            $ts.say: "Line {.fmt: '%4d'} of {$ts.buffer.elems.fmt: '%4d'} $s";
            # sleep .01;
        }
        $et = now;
        $ts.print: "Line A\c[FORM FEED]Line B";
        # sleep 1;
        $ts.print: "\rLB";
        # sleep 1;
    }
}

ScrollApp.run;

note "Bench result: ", ($et - $st), " seconds, ", $count / ($et - $st), " lines/sec";
