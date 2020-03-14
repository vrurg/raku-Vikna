use v6.e.PREVIEW;
use Vikna::App;
use Vikna::Window;
use Vikna::Events;
use Vikna::TextScroll;

class ZApp is Vikna::App {
    has @!w;
    method main {
        for ^10 {
            @!w.push: $.desktop.create-child:
                                Vikna::Window,
                                :x($_ * 5), :y($_ * 2), :30w, :10h,
                                :name('Window' ~ $_),
                                :title('Window #' ~ $_),
                                :bg-pattern(~$_);
        }
        my $info = $.desktop.create-child: Vikna::TextScroll,
                                :x($.desktop.w - 40), :y($.desktop.h - 20), :40w, :20h,
                                :name<Info>,
                                :bg-pattern(' ');
        $.flow: :name("TIMER LOOP"), {
            for ^100 -> $n {
                sleep .1;
                my $i = 10.rand.floor;
                $.desktop.to-top(@!w[$i]);
                if $info {
                    $info.say: $n.fmt('%3d'), ". Window $i -> top"
                }
            }
            $.desktop.quit;
        }
    }
}

ZApp.new( :!debugging ).run;
