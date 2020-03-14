use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Widget::Group;
also is Vikna::Widget;

use Vikna::Widget::GroupMember;
use Vikna::Events;
use Vikna::Utils;

### Command handlers ###

method cmd-addmember(::?CLASS:D: Vikna::Widget::GroupMember:D $member, ChildStrata:D $stratum) {
    self.Vikna::Widget::cmd-addchild($member, $stratum, :subscribe)
}

method cmd-removemember(::?CLASS:D: Vikna::Widget::GroupMember:D $member) {
    self.Vikna::Widget::cmd-removechild($member, :!unsubscribe)
}

method cmd-redraw {
    $.trace: "Redraw group members";
    $.for-children: {
        .cmd-redraw;
    }
    nextsame;
}

### Command senders ###

method add-member(::?CLASS:D: Vikna::Widget::GroupMember:D $member, ChildStrata $stratum = StMain) {
    $.send-command: Event::Cmd::AddMember, $member, $stratum
}

method remove-member(::?CLASS:D: Vikna::Widget::GroupMember:D $member) {
    $.send-command: Event::Cmd::RemoveMember, $member
}

### Utility methods ###
# Typically, group doesn't draw itself. Even the background.
method draw(|) { }

method event-for-children(Event:D $ev) {
    $.for-children: {
        .event($ev.clone);
    }
}

method create-member(::?CLASS:D: Vikna::Widget::GroupMember:U \wtype, |c) {
    $.trace: "CREATING A GROUP MEMBER OF ", wtype.^name;
    # my $member = $.create: wtype, :parent(self), :group(self), |c;
    my $member = $.create: wtype, :group(self), |c;
    $.add-member: $member;
    $member
}
