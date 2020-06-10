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

class SyncHandle {
    has $.id;
    has Str:D $.name = "synch";
    has Str $.tag;
    has SetHash $.await-for;

    my atomicint $next-id = 0;
    method next-tag(--> Str:D) {
        $!id = ++⚛$next-id;
        $!await-for = ().SetHash;
        $!tag = $!name ~ '$' ~ $!id;
    }
}

has SyncHandle:D $!default-sh .= new;
has SyncHandle:D $!geom-sh .= new(:name("geom-sync"));
has SetHash:D $!active-sync-handles .= new;


proto method flatten-sync(|) {*}
multi method flatten-sync(SyncHandle:D $sh, &code) {
    my $*VIKNA-GROUP-SYNC-HANDLE = $sh;
    my $ev-tag = $sh.next-tag;

    unless $!active-sync-handles {
        self.flatten-block;
    }

    $!active-sync-handles{$sh}++;

    tag-event $ev-tag, &code;

    # By default sync on all members
    unless $sh.await-for {
        self.for-children: {
            $sh.await-for{.id}++;
        }
    }
}
multi method flatten-sync(&code) {
    self.flatten-sync: $!default-sh, &code
}

sub get-sync-handle(Str $name?) is export {
    SyncHandle.new: |(:$name if $name)
}

sub sync-on(Vikna::Widget::GroupMember:D $child) is export {
    with $*VIKNA-GROUP-SYNC-HANDLE {
        .await-for{$child.id}++;
    }
    else {
        die "sync-on invoked outside of a flatten-sync context";
    }
}

method cmd-setgeom(Int:D $x, Int:D $y, Int:D $w, Int:D $h, |c) {
    self.flatten-sync: $!geom-sh, {
        self.Vikna::Widget::cmd-setgeom: $x, $y, $w, $h;
        self.for-children: {
            .cmd-setgeom(0, 0, $w, $h, |c);
        }
    }
}

method cmd-childcanvas(Vikna::Widget::GroupMember:D $child, |c) {
    callsame;
    my $ev = $*VIKNA-CURRENT-EVENT;
    if $!active-sync-handles {
        for $!active-sync-handles.keys -> $sh {
            if $sh.tag ∈ $ev.tags {
                $sh.await-for{$child.id}--;
                unless $sh.await-for {
                    $!active-sync-handles{$sh}--;
                }
            }
        }
        unless $!active-sync-handles {
            self.flatten-unblock;
            self.dispatch: Vikna::Event::ClockSignal;
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
