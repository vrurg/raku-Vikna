use v6.e.PREVIEW;
# use lib "%*ENV<HOME>/src/Raku/Terminal-Print/lib";
# use lib "%*ENV<HOME>/src/Raku/raku-Terminal-Window/lib";
use Vikna::App;
use Vikna::Events;
use Vikna::TextScroll;

my $count = 1000;

class MyScroll is Vikna::TextScroll {

    has $.st;
    has $.et;

    my class Event::Cmd::NextLine is Event::Command {
        # Uncommenting the following method will skyrocket the benchmark but would result in "batch-update" of the
        # widget. Only makes interest for experimental purposes.
        # method priority { PrioOut }
    }

    multi method event(Event::Attached:D $ev) {
        if $ev.child === self {
            $!st = now;
            $.next-line(0);
            # Send lines from a separate thread.
            # $.flow: :name('Async out'), {
            #     for ^$count -> $i {
            #         $.say: "app line ", $i.fmt(‘%4d’);
            #         sleep .05;
            #     }
            # };
        }
    }

    method cmd-nextline(UInt:D $line) {
        my $do-next = True;
        given $line {
            when * < $count {
                my $c = 10.rand.Int;
                my $s = $c x $c;
                $.say: "Line [{$line.fmt: '%4d'}], {$.buffer.elems.fmt: '%4d'} in buf, $s";
            }
            when $count {
                $.print: "Line A\c[FORM FEED]Line B";
            }
            when ($count + 1) {
                $.print: "\rLB";
            }
            when ($count + 2) {
                $.say: "\n+++";
            }
            default {
                $do-next = False;
                $.app.desktop.close;
                $!et = now;
            }
        }
        $.next-line($line + 1) if $do-next;
    }

    method next-line(UInt:D $line) {
        $.send-command: Event::Cmd::NextLine, $line;
    }
}

class ScrollApp is Vikna::App {
    has $.ts is rw;
    method main {
        $!ts = $.desktop.create-child: MyScroll, :w(80), :h(30), :x(20), :y(3), :bg-pattern(' '), :auto-clear;
    }
}

my $app = ScrollApp.new: :!debugging;
$app.run;
note "Bench result: ", ($app.ts.et - $app.ts.st), " seconds, ", $count / ($app.ts.et - $app.ts.st), " lines/sec";
