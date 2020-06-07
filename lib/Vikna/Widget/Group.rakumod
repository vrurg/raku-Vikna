use v6.e.PREVIEW;

unit class Vikna::Widget::Group;

use Vikna::Widget;
use Vikna::Widget::GroupMember;
use Vikna::Events;
use Vikna::Rect;
use Vikna::Utils;
use Vikna::X;
use AttrX::Mooish;

also is Vikna::Widget;

#my class GeomRedraw {
#    has Int $.min-ev-id is rw = Event.last-id;
#    has %.member-geom;
#}
#
#has GeomRedraw $!gredraw;

has atomicint $!sync-counter = 0;

has atomicint $!clocking = 0;
has $!refreshable = %();

### Event handlers ###

method handle-event(::?CLASS:D: Event:D $ev) {
    nextsame if $ev.dispatcher === self;
    $ev.dispatcher.handle-event($ev);
}

### Command handlers ###

method cmd-addmember(::?CLASS:D: Vikna::Widget::GroupMember:D $member, ChildStrata:D $stratum, *%c) {
    self.Vikna::Widget::cmd-addchild($member, $stratum, |%c)
}

method cmd-removemember(::?CLASS:D: Vikna::Widget::GroupMember:D $member, *%c) {
    self.Vikna::Widget::cmd-removechild($member, |%c)
}

has $!sync-tag;
has SetHash:D $!sync-awaits .= new;

method cmd-setgeom(Int:D $x, Int:D $y, Int:D $w, Int:D $h, |c) {
    my $ev-id = $*VIKNA-CURRENT-EVENT.id;
    my $tag = "geom-" ~ $ev-id;

    unless $!sync-tag {
        self.flatten-block;
    }

    $!sync-tag = $tag;

    tag-event $tag => {
        self.Vikna::Widget::cmd-setgeom: $x, $y, $w, $h;
        self.for-children: {
            .cmd-setgeom(0, 0, $w, $h, |c);
            $!sync-awaits{.id}++;
        }
    }
}

method cmd-childcanvas(Vikna::Widget::GroupMember:D $child, |c) {
    callsame;
    my $ev = $*VIKNA-CURRENT-EVENT;
    if $!sync-tag && $!sync-tag ∈ $ev.tags {
            $!sync-awaits{$child.id}--;
            unless $!sync-awaits {
                self.dispatch: Vikna::Event::ClockSignal;
                self.flatten-unblock;
                $!sync-tag = Nil;
            }
    }
}

### Command senders ###

method add-member(::?CLASS:D: Vikna::Widget::GroupMember:D $member, ChildStrata $stratum = StMain) {
    self.send-command: Event::Cmd::AddMember, $member, $stratum
}

method remove-member(::?CLASS:D: Vikna::Widget::GroupMember:D $member) {
    self.send-command: Event::Cmd::RemoveMember, $member
}

### Utility methods ###

# Typically, a group doesn't draw itself. Even the background.
method draw(|) { }

method event-for-children(Event:D $ev) {
    self.for-children: {
        .event($ev.clone);
    }
}

method create-member(::?CLASS:D: Vikna::Widget::GroupMember:U \wtype, ChildStrata:D $stratum = StMain, *%c) {
    self.trace: "CREATING A GROUP MEMBER OF ", wtype.^name;
    my $member = self.create: wtype, :group(self), |%c;
    self.add-member: $member, $stratum;
    $member
}

proto method member-geom(::?CLASS: Vikna::Widget::GroupMember $, |) {*}
multi method member-geom(::?CLASS: Vikna::Widget::GroupMember $, Int:D $x, Int:D $y, Int:D $w, Int:D $h) { ($x, $y, $w, $h) }
multi method member-geom(::?CLASS: Vikna::Widget::GroupMember $, Vikna::Rect:D $rect) { $rect }
