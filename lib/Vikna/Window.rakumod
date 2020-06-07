use v6.e.PREVIEW;

unit class Vikna::Window;

use Vikna::Widget::Group;
use Vikna::Focusable;
use Vikna::Elevatable;
use Vikna::PointerTarget;
use Vikna::Events;
use Vikna::Utils;
use Vikna::Border;
use Vikna::Widget::GroupMember;
use Vikna::Widget;
use Vikna::Rect;

also does Vikna::Elevatable;
also does Vikna::PointerTarget;
also is   Vikna::Widget::Group;
also is   Vikna::Focusable;
also does Vikna::Widget::NeverTop;

class Event::Cmd::Window::CompleteRedraw is Event::Command is export { }

class Client {
    also does Vikna::PointerTarget;
    also is Vikna::Focusable;
    also is Vikna::Widget::GroupMember;

    # Don't allow voluntary client geom change.
    method set-geom(|) { }

    method set-title(|c) { $.group.set-title(|c) }
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
                        Vikna::Border, StBack,
                        :name(self.name ~ ":Border"),
                        :w( self.w ), :h( self.h ), :x(0), :y(0),
                        # :!auto-clear,
                        ;
    }
    self.trace: "ADDING CLIENT";
    my $cgeom = Vikna::Rect.new(self.client-rect(.w, .h)) with self.geom;
    $!client = self.create-member:
                    Client,
                    :name(self.name ~ ":Client"),
                    :geom($cgeom),
                    :attr(self.attr),
                    :focused-attr(self.focused-attr),
                    # :inv-mark-color<00,30,00>,
                    :auto-clear( self.auto-clear );
    # self.inv-mark-color = '0,50,0';
}

submethod profile-default {
    attr => {
        :fg<default>, :bg<default>, :style(' '), :pattern(' ')
    },
    focused-attr => {
        :fg<white>, :bg<blue>, :style(' '), :pattern(' ')
    }
}

### Event handlers ###

### Command handlers ###

method cmd-settitle(Str:D $title) {
    my $from = $!title;
    $!title = $title;
    with $!border {
        .invalidate: 0, 0, .w, 1;
        .cmd-redraw;
    }
    self.dispatch: Event::Changed::Title, :$from, :to($title);
}

method cmd-setcolor(|c) {
    $!client.cmd-setcolor(|c);
    nextsame;
}

method cmd-setstyle(|c) {
    $!client.cmd-setstyle(|c);
    nextsame
}

method cmd-setattr(|c) {
    $!client.cmd-setattr(|c);
    nextsame
}

method cmd-addmember(::?CLASS:D: Vikna::Widget::GroupMember:D $member, |) {
    callsame;
    if $member === $!client {
        $.cmd-focus-request($member)
    }
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

method maybe-to-top {
    $.parent.to-top: self;
    nextsame;
}

### Utility methods ###
proto method client-rect(|) {*}
multi method client-rect(Vikna::Rect:D $geom) {
    self.client-rect: .w, .h with $geom
}
multi method client-rect($cw is copy, $ch is copy) {
    my $cx = 0;
    my $cy = 0;
    if $!border {
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    $cx, $cy, $cw, $ch
}

multi method member-geom(::?CLASS:D: Client, Int:D $, Int:D $, Int:D $w, Int:D $h) {
    |self.client-rect($w, $h)
}
multi method member-geom(::?CLASS:D: Client, Vikna::Rect:D $rect) {
    Vikna::Rect.new: |self.client-rect($rect.w, $rect.h)
}
multi method member-geom(::?CLASS:D: Vikna::Border, Int:D $, Int:D $, Int:D $w, Int:D $h) {
    0, 0, $w, $h
}
multi method member-geom(::?CLASS:D: Vikna::Border, Vikna::Rect:D $rect) {
    $rect.clone: :0x, :0y;
}
