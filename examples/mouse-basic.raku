use v6.e.PREVIEW;
use Vikna::App;
use Vikna::Window;
use Vikna::Events;
use Vikna::TextScroll;
use Vikna::PointerTarget;

# note Vikna::Window.^mro.map( *.^name ).join(", ");
# exit;

class MRep
    is Vikna::TextScroll
    does Vikna::PointerTarget
    is Vikna::Focusable {
    submethod profile-default {
        attr => {
            :fg(''), :bg(''), :pattern(' '),
#            :fg<default>, :bg<default>, :pattern(' ')
        },
#        focused-attr => {
#            :fg<black>, :bg<cyan>, :pattern<_>
#        }
    }
    multi method event(::?CLASS:D: Event::Attached:D $ev) {
        if $ev.child === self {
            self.subscribe: $.parent.parent, -> $pev {
                given $pev {
                    when Event::ZOrderish {
                        self.say: $pev
                    }
                    when Event::Focus::In || Event::Focus::Out {
                        self.say: $pev
                    }
                }
            }
        }
        nextsame
    }
    multi method event(::?CLASS:D: Event::Mouse:D $ev) {
        self.say: $ev;
        nextsame
    }
    multi method event(::?CLASS:D: Event::Mouse::Enter:D $ev) {
        self.say: $ev;
        nextsame
    }
    multi method event(::?CLASS:D: Event::Mouse::Leave:D $ev) {
        self.say: $ev;
        nextsame
    }
    multi method event(::?CLASS:D: Event::ZOrderish:D $ev) {
        self.say: $ev;
        nextsame
    }
}

class MWin is Vikna::Window {
    multi method event(::?CLASS:D: Event::Attached:D $ev) {
        self.trace: "GOT ATTACHED FOR ", $ev.child.name;
        if $ev.child === $.client {
            self.subscribe-to-child:
                self.create-child: MRep, :0x, :0y, w => $.client.w, h => $.client.h, :name("MRep" ~ $.name), :wrap, ;
        }
        nextsame;
    }
#    multi method event(::?CLASS:D: Event::Attached:D $ev) {
#        self.trace: "HAVE ATTACHED from { $ev.origin }: ", $ev.child.name, " to ", $ev.parent.name;
#        if $ev.child ~~ MRep {
#            start {
#                for ^3 {
#                    $ev.child.say: "Line $_"
#                }
#            }
#        }
#    }
}

# note "MWin mro: ", MWin.^mro_unhidden.map( *.^name ).join(", ");
# exit;

class MApp is Vikna::App {
    has @!w;
    method main {
        for ^3 {
            my $w = ($.desktop.w * 2 / 3 ).Int;
            my $h = 15;
            my $dy = (($.desktop.h - $h) / 2).Int;
            my $dx = ($.desktop.w / 10).Int;
            if $_ == 0 {
                $w = ($.desktop.w * 7 / 8 ).Int;
                $h = ($.desktop.h / 2).Int;
            }
            @!w.push: $.desktop.create-child:
                MWin, :x($_ * $dx), :y($_ * $dy), :$w, :$h, :name('Window' ~ $_), :title('Window #' ~ $_), :pattern(~$_);
        }
    }
}

MApp.new(:!debugging).run;
