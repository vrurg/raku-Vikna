use v6.e.PREVIEW;
use Vikna::Widget::Group;
unit class Vikna::Window;
also is Vikna::Widget::Group;

use Vikna::Events;
use Vikna::Utils;
use Vikna::Border;
use Vikna::Widget::GroupMember;

class Client is Vikna::Widget::GroupMember {
    # Don't allow voluntary client geom change.
    method set-geom(|) { }
}

has Str:D $.title = "";
has Vikna::Border $.border;
has Client $.client handles qw<
                                cmd-addchild cmd-removechild cmd-setbgpattern
                                AT-KEY EXISTS-KEY DELETE-KEY get-child
                            >;

submethod TWEAK(Bool:D :$border = True) {
    if $border {
        self.trace: "ADDING BORDER";
        $!border = self.create-member:
                        Vikna::Border,
                        :name(self.name ~ ":Border"),
                        :w( self.w ), :h( self.h ), :x(0), :y(0),
                        :auto-clear;
    }
    self.trace: "ADDING CLIENT";
    $!client = self.create-member:
                    Client,
                    :name(self.name ~ ":Client"),
                    geom => self.client-rect(self.geom),
                    :bg-pattern(self.bg-pattern // ' '),
                    :bg(self.bg), :fg(self.fg),
                    :color<black blue>,
                    # :inv-mark-color<00,50,00>,
                    :auto-clear( self.auto-clear );
    # self.inv-mark-color = '0,50,0';
}

### Command handlers ###

method cmd-settitle(Str:D $title) {
    my $old-title = $!title;
    $!title = $title;
    with $!border {
        .invalidate: 0, 0, $.w, 1;
        .cmd-redraw;
    }
    self.dispatch: Event::Changed::Title, :$old-title, :$!title;
}

method cmd-setgeom(Vikna::Rect:D $geom) {
    $.trace: "WINDOW GEOM TO {$geom}";
    self.Vikna::Widget::cmd-setgeom($geom, :no-draw);
    $!client.cmd-setgeom: $.client-rect($geom), :no-draw;
    if $!border {
        $!border.cmd-setgeom: Vikna::Rect.new(0, 0, $geom.w, $geom.h), :no-draw;
    }
    $.cmd-redraw;
    $.trace: "WINDOW GEOM SET {$.geom}";
}

method cmd-redraw {
    $!border.cmd-redraw;
    $!client.cmd-redraw;
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

method resize(Int:D $w is copy where * > 0 = $.w, Int:D $h is copy where * > 0 = $.h) {
    my $min = $!border ?? 4 !! 2;
    $w max= $min;
    $h max= $min;
    nextwith($w, $h)
}

method child-canvas(::?CLASS:D: |c) {
    $.cmd-childcanvas: |c;
}

### Utility methods ###
method client-rect(Vikna::Rect:D $geom) {
    my ($cx, $cy, $cw, $ch) = (0, 0, $geom.w, $geom.h);
    if $!border {
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    Vikna::Rect.new: $cx, $cy, $cw, $ch
}
