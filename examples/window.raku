use v6.e.PREVIEW;
use Vikna::App;
use Vikna::Window;
use Vikna::Label;
use Vikna::Events;
use Vikna::TextScroll;
use Vikna::Utils;
use AttrX::Mooish;

class EventReporter is Vikna::TextScroll {
    multi method event(Event::Attached:D $ev) {
        $.fit-into;
        $.subscribe: $.app.desktop;
        nextsame
    }
    multi method subscription-event(Event::Input:D $ev) {
        given $ev {
            when Event::Kbd::Control {
                $.say: "Kbd ", $ev.^shortname.lc, ($ev.char ?? " char: " ~ $ev.char !! 'no char'),
                        ", mods: ", $ev.modifiers.keys.join(", "), ", key:" ~ $ev.key;
            }
            when Event::Kbd {
                $.say: "Kbd ", $ev.^shortname.lc, ($ev.char ?? " char: " ~ $ev.char !! 'no char'),
                        ", mods: ", $ev.modifiers.keys.join(", ");
            }
            default {
                $.say: $ev.^name;
            }
        }
    }
    multi method event(Event::Screen::Geom:D $ev) {
        $.trace: "Screen geom from subscription: ", $ev;
        my ($pw, $ph) = .w, .h given $ev.to // $.parent.geom;
        my $w = 10 max ($pw / 3).ceiling;
        my $h = 5 max ($ph / 2).ceiling;
        $.cmd-setgeom: Vikna::Rect.new($pw - $w, $ph - $h, $w, $h);
        # $.fit-into: geom => $ev.to;
        $.cmd-textscroll-addtext: "SCREEN GEOM: " ~ $ev.to ~ "\n";
        # $.say: "SCREEN GEOM: ", $ev.to;
    }
    method fit-into(:$geom) {
        $.trace: "FITTING INTO PARENT: ", $.parent.name;
        my ($pw, $ph) = .w, .h given $geom // $.parent.geom;
        my $w = 10 max ($pw / 3).ceiling;
        my $h = 5 max ($ph / 2).ceiling;
        $.set-geom: $pw - $w, $ph - $h, $w, $h;
    }
}

class Moveable is Vikna::Window {
    has Iterator $!stages is mooish(:lazy);
    has $!ready4next;
    has $!done;

    my class Stage {
        has Int:D $.stage is required;
        has Int:D $.step is required;
        has Vikna::Rect:D $.geom is required;
        has $.bg is required;
        has $.fg is required;
    }

    method TWEAK {
        self.dispatch: Event::Idle;
    }

    my class Event::NextStage is Event::Informative {
        has Int:D $.stage is required;
        method default-priority { PrioImmediate }
    }
    my class Event::Cmd::NextStep is Event::Command { }

    method !build-stages {
        my Int:D $stage = 0;
        my Int:D $step = 0;
        my Int:D $steps = 0;
        my ($dest-w, $dest-h, $dest-x, $dest-y);
        my ($dw, $dh, $dx, $dy);
        my ($green, $red, $dc);
        my $color-trend = 1;
        my Vikna::Rect $orig;
        Seq.from-loop({
            if $stage <= 10 {
                if $step >= ($steps min 100) {
                    $orig = $.geom.clone;
                    my $desktop-w = $.app.desktop.w;
                    my $desktop-h = $.app.desktop.h;
                    $dest-w = ($desktop-w / 2).rand.Int + 4;
                    $dest-h = ($desktop-h / 2).rand.Int + 4;
                    $dest-x = ($desktop-w - $dest-w).rand.Int;
                    $dest-y = ($desktop-h - $dest-h).rand.Int;
                    $dw = $dest-w - $orig.w;
                    $dh = $dest-h - $orig.h;
                    $dx = $dest-x - $orig.x;
                    $dy = $dest-y - $orig.y;
                    $steps = $dx.abs max $dy.abs; # Iterate over the longer change
                    $color-trend = -$color-trend;
                    $green = 150 + (50 * -$color-trend);
                    $red  = 150 + (50 * $color-trend);
                    $dc = 100 / $steps;
                    $step = -1;
                    ++$stage;
                    # $*ERR.print: "New stage $stage: moving to $dest-x, $dest-y $dest-w x $dest-h; steps: $steps";
                    $.trace: "New stage $stage: moving to $dest-x, $dest-y $dest-w x $dest-h; steps: $steps";
                }
                ++$step;
                my $ds = $step / $steps;
                my $cur-x = ($orig.x + $dx × $ds).Int;
                my $cur-y = ($orig.y + $dy × $ds).Int;
                my $cur-w = ($orig.w + $dw × $ds).Int;
                my $cur-h = ($orig.h + $dh × $ds).Int;
                Stage.new:
                            :$stage, :$step,
                            geom => Vikna::Rect.new($cur-x, $cur-y, $cur-w, $cur-h),
                            fg => (($red + ($step * $dc * -$color-trend)).Int, ($red + ($step * $dc * -$color-trend)).Int, 0).join(","),
                            bg => (0, ($green + ($step * $dc * $color-trend)).Int, 0).join(","),
            }
            else {
                Nil
            }
        }).iterator
    }

    method cmd-nextstep {
        return if $.closed;
        my $stage = $!stages.pull-one;
        unless $stage {
            $!done = True;
            $.quit;
            return;
        }

        $.dispatch: Event::NextStage, stage => $stage.stage if $stage.step == 0;

        # $*ERR.print: "Stage ", $stage.stage, ", step ", $stage.step, ": ", $stage.geom, "\r";
        $.trace: "Stage ", $stage.stage, ", step ", $stage.step, ": ", $stage.geom;
        my $lbl = self<info-lbl>;
        my $ttl-pfx = $lbl ?? $lbl.ttl-pfx !! "";
        my $desktop = $.app.desktop;
        my $sw = $desktop<Static>;
        $.redraw-hold: {
            $.set-geom: $stage.geom.clone;
            $.set-color: fg => $stage.fg, bg => $stage.bg;
            $.set-title: $ttl-pfx ~ "geom({$stage.stage}): " ~ $stage.geom;
            if $sw {
                $sw.set-title: "Stage " ~ $stage.stage;
                .set-text: ~$stage.geom with $sw<s-info-lbl>;
            }
            .set-text: "Step " ~ $stage.step with $lbl;
        }
        $!ready4next = True;
    }

    multi method event(Event::NextStage:D $ev) {
        self<info-lbl>.set-hidden( ! $ev.stage % 2 );
        $.set-style: [($ev.stage % 2 == 0) ?? VSUnderline !! VSItalic];
        my $close-at-stage = 5;
        if $ev.stage < $close-at-stage {
            $.app.desktop<Static>.set-bg-pattern("[{$ev.stage}]");
        }
        elsif $ev.stage == $close-at-stage {
            $.trace: "Closing Static window";
            $.app.desktop<Static>.close;
        }
    }

    multi method event(Event::Updated:D $ev) {
        if !$!done
            && $!ready4next
            && $ev.origin === $.app.desktop
            && $ev.dispatcher === self
        {
            $.trace: "Next step upon ", $ev;
            $!ready4next = False;
            $.next-step;
        }
        nextsame;
    }

    multi method event(Event::Attached:D $ev) {
        $.trace: "WINDOW ATTACHED, CLIENT CODE";
        if $ev.child === self {
            $.nop.head.completed.then: {
                $.next-step;
            }
        }
        nextsame;
    }

    multi method event(Event::Idle:D $ev) {
        $.trace: "IDLED";
        $.dispatch: Event::Idle;
    }

    method next-step {
        $.send-command: Event::Cmd::NextStep;
    }
}

class MovingApp is Vikna::App {
    method main {
        my $mw = $.desktop.create-child: Moveable, :0x, :0y, w => ($.desktop.w / 3).Int, h => ($.desktop.h / 3).Int,
                                                :name<Moveable>, :title('Moveable Window'), :pattern<I>,
                                                # :auto-clear,
                                                :bg<blue>,
                                                :style('underline'),
                                                # :inv-mark-color<00,50,00>,
                                                ;
        my $lbl = $mw.create-child: Vikna::Label,
                                    :3x, :10y, :1h, :30w,
                                    :name<info-lbl>, :text('Info Label'),
                                    :bg('0,80,150'),
                                    :style('underline italic');
        $.desktop.create-child: EventReporter, StBack,
                                x => $.desktop.w - 50,
                                y => $.desktop.h - 20,
                                :50w, :20h,
                                :name<EventList>, :pattern(' '), :bg<black>, :fg<cyan>;
        $lbl does role {
            has $.ttl-pfx = "";
            multi method event(Event::Visible:D $ev) {
                $!ttl-pfx = "V:";
            }
            multi method event(Event::Invisible:D $ev) {
                $!ttl-pfx = "I:";
            }
        };
        my $sw = $.desktop.create-child:
                    Vikna::Window,
                    :30x, :5y, :40w, :5h,
                    :name<Static>,
                    :bg<black>, :fg<white>,
                    :style(VSTransparent),
                    focused-attr => {
                        style => VSTransparent,
                    },
                    # :inv-mark-color<00,50,00>,
                    :title('Static Window');
        $sw.create-child: Vikna::Label, :0x, :0y, :38w, :1h, :name<s-info-lbl>, :text('info lbl');
        # $.desktop.sync-events;
    }
}

MovingApp.new( :!debugging ).run;
