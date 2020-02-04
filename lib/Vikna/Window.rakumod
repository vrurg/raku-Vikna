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
has Client $.client handles qw<
                                cmd-addchild cmd-removechild cmd-setbgpattern
                                AT-KEY EXISTS-KEY DELETE-KEY get-child
                            >;

submethod TWEAK(Bool:D :$border = True) {
    my ($cx, $cy, $cw, $ch) = (0, 0, self.w, self.h);
    if $border {
        self.trace: "ADDING BORDER";
        $!border = self.create-member:
                        Vikna::Border,
                        :name(self.name ~ ":Border"),
                        :w( $cw ), :h( $ch ), :x(0), :y(0),
                        :!auto-clear;
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    self.trace: "ADDING CLIENT";
    $!client = self.create-member:
                    Client,
                    :name(self.name ~ ":Client"),
                    :x( $cx ), :y( $cy ), :w( $cw ), :h( $ch ),
                    :bg-pattern(self.bg-pattern // ' '),
                    :color<black blue>,
                    :auto-clear( self.auto-clear );
    # self.inv-mark-color = '0,50,0';
}

### Event handlers

multi method child-event(Event::Changed::Geom:D $ev) {
    if $ev.origin === $!border {
        # Apply size changes after the border.
        self.Vikna::Widget::cmd-setgeom(Vikna::Rect.new($.x, $.y, .w, .h)) given $ev.geom;
    }
}

### Command handlers ###

method cmd-settitle(Str:D $title) {
    my $old-title = $!title;
    $!title = $title;
    with $!border {
        .invalidate: 0, 0, $.w, 1;
        .redraw;
    }
    self.dispatch: Event::Changed::Title, :$old-title, :$!title;
}

method cmd-setgeom(Vikna::Rect:D $geom) {
    $.trace: "WINDOW GEOM TO {$geom}";
    # $.redraw-hold: {
        $!client.fit($geom);
        given $geom {
            if $!border {
                $!border.resize: .w, .h;
                # For now change position only to keep our size in sync with border. The size would be updated upon border
                # geom change.
                self.Vikna::Widget::cmd-setgeom(Vikna::Rect.new(.x, .y, $.w, $.h), :no-draw);
            }
            else {
                self.Vikna::Widget::cmd-setgeom($_, :no-draw);
            }
        }
    # }
    $.trace: "WINDOW GEOM SET {$.geom}";
}

method cmd-setcolor(|c) {
    $!client.cmd-setcolor(|c);
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
