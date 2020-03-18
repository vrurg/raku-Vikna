use v6.e.PREVIEW;
use Vikna::App;
use Vikna::Window;
use Vikna::Label;
use Vikna::Events;
use Vikna::Utils;
use Vikna::Button;
use Vikna::TextScroll;
use AttrX::Mooish;

class ButWin is Vikna::Window {
    multi method event(Event::Button::Press:D $ev) {
        $.set-title: "Button " ~ $ev.origin.name ~ " press " ~ now.DateTime.local.hh-mm-ss;
    }
}

class JumpBut is Vikna::Button {
    # proto method event(::?CLASS:D: Event:D) {*}
    multi method event(Event::Button::Press:D $ev) {
        my $next-win = $.parent.group.next-sibling: :loop;
        $.trace: "Switching to parent ", $next-win;
        my $vf = $*VIKNA-FLOW;
        $.detach.head.completed.then: {
            my $*VIKNA-FLOW = $vf;
            $.trace: "Adding myself to widget ", $next-win;
            $next-win.add-child: self;
            $.target = $next-win;
        };
    }
    # multi method event($ev) {
    #     unless $ev ~~ Event::Mouse::Move | Event::Updated {
    #         $.app.desktop<EvTrace>.say: self, ": ", $ev;
    #     }
    #     nextsame;
    # }
}

class ButApp is Vikna::App {
    method main {
        my $w = ($.desktop.w / 2).Int;
        my $dx = ($.desktop.w / 2).ceiling;
        # $.desktop.create-child: Vikna::TextScroll, StBack,
        #                         x => 0,
        #                         y => $.desktop.h - 20,
        #                         w => ($.desktop.w / 2).Int,
        #                         h => 20,
        #                         name => "EvTrace",
        #                         pattern => ' ',
        #                         ;
        for ^2 -> $i {
            my $win = $.desktop.create-child: ButWin,
                                    :name("Win$i"), :title("Window $i"),
                                    :x( $dx * $i ), :5y, :$w, :10h,
                                    ;
            my $wcw = $w - 2;
            my $wdx = (($wcw / 2 - 10) / 2).Int;
            $win.create-child: JumpBut,
                                :name("ButOk$i"), :x($wdx), :y($i + 2), :10w,
                                :text("Ok$i"),
                                :target($win),
                                ;
            $win.create-child: Vikna::Button,
                                :name("ButCancel$i"), :x($w - 2 - $wdx - 10), :y($i + 2), # :10w,
                                :text("Cancel$i"),
                                :target($win),
                                :use3d,
                                ;
        }
    }
}

ButApp.new( :!debugging ).run;
