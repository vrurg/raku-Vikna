use v6.e.PREVIEW;
use Vikna::Widget::Group;
unit class Vikna::Window is Vikna::Widget::Group;

use Vikna::Events;
use Vikna::Utils;
use Vikna::Border;
use Vikna::Widget::GroupMember;

class Client is Vikna::Widget::GroupMember {
    method fit(Vikna::Rect:D $geom) {
        my ($w, $h) = $.parent.client-size($geom);
        self.Vikna::Widget::resize($w, $h)
    }
    # Don't allow voluntary client size change.
    method resize { }
}

has Str:D $.title = "";
has Vikna::Border $.border;
has Client $.client handles <cmd-addchild cmd-removechild>;

submethod TWEAK(Bool:D :$border = True) {
    my ($cx, $cy, $cw, $ch) = (0, 0, self.w, self.h);
    if $border {
        $!border = self.create-child:
                        Vikna::Border,
                        :group(self),
                        :w( $cw ), :h( $ch ), :x(0), :y(0),
                        :!auto-clear;
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    $!client = self.create-child:
                    Client,
                    :x( $cx ), :y( $cy ), :w( $cw ), :h( $ch ),
                    :group( self ),
                    :bg-pattern('.-+'),
                    :color<black blue>,
                    :auto-clear( self.auto-clear );
}

### Command handlers ###

method cmd-settitle(Str:D $title) {
    my $old-title = $!title;
    $!title = $title;
    self.dispatch: Event::TitleChange, :$old-title, :$!title
}

method cmd-setgeom(Vikna::Rect:D $geom) {
    $!client.fit($geom);
    $!border.cmd-setgeom: Vikna::Rect.new(.w, .h) given $geom;
    nextsame;
}

method cmd-setcolor(|c) {
    $!client.cmd-setcolor(|c);
    nextsame;
}

### Command senders ###
method set-title(Str:D $title) {
    self.send-command: Event::Cmd::SetTitle, $title;
}

# method redraw {
#     $.hold-events: Event::RedrawRequest, :kind(HoldFirst), {
#         my $canvas = self.begin-draw;
#         self.draw( :$canvas );
#         self.end-draw( :$canvas );
#     }
# }

method resize(Int:D $w is copy where * > 0 = $.w, Int:D $h is copy where * > 0 = $.h) {
    my $min = $!border ?? 4 !! 2;
    $w max= $min;
    $h max= $min;
    nextwith($w, $h)
}

### Utility methods ###
method client-size(Vikna::Rect:D $geom) {
    my $bw = $!border ?? 2 !! 0;
    ($geom.w - $bw, $geom.h - $bw)
}

multi method event(Event::TitleChange:D) {
    $.invalidate: 0, 0, $.w, 1;
    $.redraw;
}
