#!/usr/bin/env raku
use v6.e.PREVIEW;
use Vikna::Label;
use Vikna::App;
use Vikna::TextScroll;
use Vikna::Events;
use Vikna::Utils;
use AttrX::Mooish;

BEGIN $*SCHEDULER = ThreadPoolScheduler.new(:max_threads(2000));

class Event::ColorRotate is Event::Informative { }

class ColorLabel is Vikna::Label {
    multi method event(Vikna::Event::Redrawn:D $ev) {
        if $.initialized {
            $.app.reporter.print: $.name, " rdrwn  \r";
        }
        nextsame
    }
}

class Rainbow is Vikna::Widget {
    has $.lw = 6;
    has $.max-dist is mooish(:lazy);
    has $.color-shift = 0;
    has %!childp;
    has atomicint $!all-added = 0;
    has $!awaiting = False;

    method build-max-dist {
        $.w min $.h
#        sqrt(($.w div $!lw)² + $.h²)
    }

    method l-color($x, $y, $shift) {
        my $R = sqrt($x² + $y²);
        my \D = π × 4 * $R / $!max-dist;
        sub clr($phase --> UInt:D) {
            (255 * ((1 + sin(D + π × $phase / 3 + $shift)) / 2)).Int
        }
        my $bg = (^3).map({ clr($_) }).join(",");
    }

    method cmd-refresh {
        $.app.reporter.say: "cmd refresh, ", $.flatten-blocked;
        callsame;
        $.app.reporter.say: "refreshed";
    }

    method cmd-childcanvas(Vikna::Widget:D $child, |) {
        callsame;
        with %!childp{$child.id} {
            if .status ~~ Planned {
                .keep(True);
            }
        }
    }

    method set-await(Vikna::Widget:D $child, $promise = Promise.new) {
        %!childp{$child.id} = $promise;
        ++⚛$!all-added;
    }

    method await-redraws {
        $!awaiting = True;
        self.flow: :name('Await children'), {
            await %!childp.values;
            %!childp = ();
            self.flatten-unblock;
            $.app.reporter.say: "\nAll ", self.elems, " done, next, ", self.flatten-blocked;
            self.dispatch: Event::ColorRotate;
        }
    }

    multi method event(Event::Init:D $ev) {
        self.flatten-block;
        self.flow: :name('Fill the rainbow'), {
            my $xcount = $.w div 6;
            my $reporter = $.app.reporter;
            for ^$xcount -> $x {
                $reporter.say: "X: ", $x.fmt('%10d');
                for ^$.h -> $y {
                    my $idx = $x.fmt('%02d') ~ $y.fmt('%02d');
                    my $c = self.create-child:
                        ColorLabel,
                        :w($!lw), :h(1), :x($x × $!lw), :$y, :attr{
                            :fg<white>, :bg(self.l-color($x, $y, 0)), :pattern(' ')
                        },
                        :text($idx), :name("L" ~ $idx);
                    self.set-await: $c; #, $c.updated;
                }
            }
            self.await-redraws;
            $reporter.say: "DONE!";
        }
        nextsame
    }

    multi method event(Event::ColorRotate:D $ev) {
        $!color-shift += π / 3;
        my $reporter = $.app.reporter;
        $reporter.say: "SHIFT: ", $!color-shift.fmt('%.4f');
        self.flatten-block;
        self.flow: :name('SHIFT'), {
            my @evp;
                self.children.race(:batch(8), :degree($*KERNEL.cpu-cores)).map: -> $c {
                    if $c ~~ Vikna::Label {
                        my $bg = self.l-color($c.x div $!lw, $c.y, $!color-shift);
                        $c.set-color: :fg<white>, :$bg;
                        self.set-await: $c; #, $c.status-reset;
                        $c.invalidate;
                        $c.redraw;
                    }
                }
            self.await-redraws;
        }
        $.app.reporter.say: "Shifted";
    }

    multi method event(Vikna::Event::Flattened:D $ev) {
        $.app.reporter.say: "FLATTENED! ";
    }
}

class ThreadApp is Vikna::App {
    has $.reporter;
    method main(|) {
        constant INFO-W = 25;
        $!reporter = $.desktop.create-child:
            Vikna::TextScroll, StBack,
            x => $.desktop.w - INFO-W,
            y => 1,
            :w(INFO-W), :h($.desktop.h - 1),
            :name<Reporter>,
            :attr{
                :pattern(' '), :bg(0x10, 0x10, 0x10), :fg<yellow>;
            };
        my $tt = $.desktop.create-child: Vikna::Label,
            :name<TickTok>,
            :x($.desktop.w - INFO-W), :y(0), :w(INFO-W), :h(1),
            :text('tick-tock'),
            :fg<white>, :bg(0x80, 0x80, 0x80);
        $.desktop.create-child:
            Rainbow, :x(0), :y(0), :w($.desktop.w - 25), :h($.desktop.h);
        for ^Inf -> $counter {
            sleep 1;
            $tt.set-text: "tick-tok " ~ $counter.fmt('%8d');
        }
    }
}

my $tapp = ThreadApp.new(:!debugging);
$tapp.run;
