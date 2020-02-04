use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Widget::Group;
also is Vikna::Widget;

use Vikna::Widget::GroupMember;
use Vikna::Events;

# proto method event(::?CLASS:D: Event:D $ev) {
#     {*}
#     unless $ev ~~ Event::Command {
#         self.event-for-children: $ev
#     }
# }
#
# # Re-dispatch commands to their originators.
# multi method event(::?CLASS:D: Event::Command:D $ev) {
#     # note self.name, " RE-DISPATCH COMMAND {$ev.^shortname} TO origin=", $ev.origin.name, ", dispatcher:", $ev.dispatcher.name;
#     if $ev.origin === self {
#         self.Vikna::Widget::event($ev)
#     } else {
#         $ev.origin.event($ev);
#     }
# }
#
# multi method event(|c) { self.Vikna::Widget::event(|c) }

### Command handlers ###

method cmd-addmember(::?CLASS:D: Vikna::Widget::GroupMember:D $member) {
    self.Vikna::Widget::cmd-addchild($member, :subscribe)
}

method cmd-removemember(::?CLASS:D: Vikna::Widget::GroupMember:D $member) {
    self.Vikna::Widget::cmd-removechild($member, :!unsubscribe)
}

### Command senders ###

method add-member(::?CLASS:D: Vikna::Widget::GroupMember:D $member) {
    $.send-command: Event::Cmd::AddMember, $member
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
