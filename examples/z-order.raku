use v6.e.PREVIEW;
use Vikna::App;
use Vikna::Desktop;
use Vikna::Window;
use Vikna::Events;
use Vikna::TextScroll;
use AttrX::Mooish;

constant NUM-WIN = 10;

class Event::ChangeTop is Vikna::Event {
    method default-priority { PrioCommand }
};

class ZWin is Vikna::Window {
    has $!change-top = False;
    multi method event(Event::Focus::In:D $ev) {
        $!change-top = True;
    }
    multi method event(Event::Redrawn:D $ev) {
        if $!change-top {
            $.app.desktop<Info>.say: $.name, " redrawn focused";
            $.app.desktop.dispatch: Event::ChangeTop;
            $!change-top = False;
        }
        nextsame
    }
}

class ZDesktop is Vikna::Desktop {
    has Vikna::TextScroll $.info;
    has $.counter = 20;
    has $.left-attach = NUM-WIN;
    has $!last-change;

    multi method event(Event::Init:D $ev) {
        for ^NUM-WIN {
            self.create-child:
                ZWin,
                :x($_ * 5), :y($_ * 2), :30w, :10h,
                :pattern(~$_),
                :name('Window' ~ $_),
                :title('Window #' ~ $_),
            ;
        }
        $!last-change = now;
        $!info = self.create-child:
            Vikna::TextScroll,
            :x($.w - 40), :y($.h - 20), :40w, :20h,
            :name<Info>, :pattern(' ');
    }

    multi method event(Event::ChangeTop:D $ev) {
        my $i;
        my $w;
        my $changed-at = now;
        repeat {
            $i = NUM-WIN.rand.floor;
            $w = self{'Window' ~ $i};
        } while $w.in-focus;
        my $vf = $*VIKNA-FLOW;
        $.app.screen.availability_promise.then: {
            my $*VIKNA-FLOW = $vf;
            self.to-top: $w;
            if $!info {
                $!info.say: $!counter.fmt('%3d'), ". Window $i -> top; ", ($changed-at - $!last-change).fmt('%.4f');
                $!last-change = $changed-at;
            }
            --$!counter;
            unless $!counter > 0 {
                self.quit
            }
        }
    }

    multi method event(Event::Attached:D $ev) {
        if $ev.parent === self && $ev.child ~~ ZWin {
            --$!left-attach;
            .say: $ev.child.name, " prepared" with $!info;
        }
    }
}

class ZApp is Vikna::App {
    method main {
    }
}

ZApp.new( :!debugging, :desktop-class(ZDesktop) ).run;
