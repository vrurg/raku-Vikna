#!/usr/bin/env raku

# NOTE! This example is pushing the limits of an all-native Raku application. It is not recommended to be ran in a
# console with more than 90 columns and 30 lines. On slow systems event smaller window is recommended. In either case,
# be patient, please!

use v6.e.PREVIEW;
use Vikna::Label;
use Vikna::App;
use Vikna::TextScroll;
use Vikna::Events;
use Vikna::Utils;
use AttrX::Mooish;

BEGIN $*SCHEDULER = ThreadPoolScheduler.new(:max_threads(2000));

constant WAVES = 2;

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
    has atomicint $!status-code = 0;
    has $.loop;

    method build-max-dist {
        $.w min $.h
#        sqrt(($.w div $!lw)² + $.h²)
    }

    method l-color($x, $y, $shift) {
        my $R = sqrt($x² + $y²);
        my \D = π × WAVES × 2 × $R / $!max-dist;
        sub clr($phase --> UInt:D) {
            (255 * ((1 + sin(D + π × $phase / 3 + $shift)) / 2)).Int
        }
        my $bg = (^3).map({ clr($_) }).join(",");
    }

    method cmd-refresh {
        $.app.reporter.say: "cmd refresh, ", $.flatten-blocked;
        callsame;
        $.app.reporter.say: " - refreshed ";
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
        $!status-code ⚛= 1;
        self.flow: :name('Await children'), {
            await %!childp.values;
            %!childp = ();
            self.flatten-unblock;
            $.app.reporter.say: "\nAll ", self.elems, " done, next, ", self.flatten-blocked;
            $!status-code ⚛= 2;
        }
    }

    multi method event(Event::Init:D $ev) {
        self.flatten-block;
        self.flow: :name('Fill the rainbow'), {
            my $xcount = $.w div 6;
            my $ycount = $.h;
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
        my $now = now;
        if $!loop {
            $reporter.say: "LOOP: ", ($now - $!loop).fmt('%.2f'), " sec.";
        }
        $!loop = $now;
        self.flatten-block;
        self.flow: :name('SHIFT'), {
            self.invalidate;
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
        if $!status-code == 2 {
            self.dispatch: Event::ColorRotate;
            $.app.reporter.say: "FLATTENED! ";
            $!status-code ⚛= 0;
        }
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
            Rainbow,
            :x(0), :y(0),
            :w($.desktop.w - 25), :h($.desktop.h),
#            :w(48), :h(8),
            ;
        for ^Inf -> $counter {
            sleep 1;
            $tt.set-text: "tick-tok " ~ $counter.fmt('%8d');
        }
    }
}

my $tapp = ThreadApp.new(:!debugging);
$tapp.run;
