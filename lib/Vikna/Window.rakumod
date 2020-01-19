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
    method cmd-addchild($chld) {
        $.trace: "WINDOW CLIENT ADD CHILD ", $chld.WHICH;
        nextsame;
    }
}

has Str:D $.title = "";
has Vikna::Border $.border;
has Client $.client handles <cmd-addchild cmd-removechild>;

submethod TWEAK(Bool:D :$border = True) {
    my ($cx, $cy, $cw, $ch) = (0, 0, self.w, self.h);
    if $border {
        self.trace: "ADDING BORDER";
        $!border = self.create:
                        Vikna::Border,
                        :parent(self),
                        :group(self),
                        :w( $cw ), :h( $ch ), :x(0), :y(0),
                        :!auto-clear;
        self.Vikna::Parent::add-child($!border);
        # Invalidate manually because typically widget's add-child would do it for us.
        $!border.invalidate;
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    self.trace: "ADDING CLIENT";
    $!client = self.create:
                    Client,
                    :parent(self),
                    :group( self ),
                    :x( $cx ), :y( $cy ), :w( $cw ), :h( $ch ),
                    :bg-pattern(self.bg-pattern // '∙-□-'), # DEBUG
                    :color<black blue>,
                    :auto-clear( self.auto-clear );
    self.Vikna::Parent::add-child($!client);
    # Invalidate manually because typically widget's add-child would do it for us.
    $!client.invalidate;
    # self.inv-mark-color = '0,50,0';
}

### Command handlers ###

method cmd-settitle(Str:D $title) {
    my $old-title = $!title;
    $!title = $title;
    $.border.invalidate: 0, 0, $.w, 1;
    $.redraw;
    self.dispatch: Event::TitleChange, :$old-title, :$!title;
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

method cmd-redraw(Promise:D $redrawn) {
    my @cpromises;
    $.for-children: {
        my $cp = Promise.new;
        .cmd-redraw($cp);
        @cpromises.push: $cp;
    }
    await @cpromises;
    nextsame;
}

### Command senders ###
method set-title(Str:D $title) {
    self.send-command: Event::Cmd::SetTitle, $title;
}

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
