use v6.e.PREVIEW;

unit role Vikna::Focusable;

use Vikna::Widget;
use Vikna::Events;
use Vikna::WAttr;
use Hash::Merge;

has ::?ROLE $.focus;
has Bool:D $.in-focus = False;

# Shall we auto-focus the topmost child?
has Bool:D $.focus-topmost = False;

has Vikna::WAttr $.focused-attr;

submethod profile-checkin(%profile, %, %, %) {
    my @focused-keys = <focused-fg focused-bg focused-style focused-pattern>;
    return unless any %profile{'focused-attr', |@focused-keys};
    unless %profile<focused-attr> ~~ Vikna::WAttr {
        my %fa = $_ with %profile<focused-attr>;
        %fa{$_} //= %profile{ S/^focused\-// } for @focused-keys;
        %profile<focused-attr> = %profile<attr>.dup(|%fa);
    }
    %profile{@focused-keys}:delete;
}

multi method route-event(::?ROLE:D: Event::Focusish:D $ev) is default {
    if $!in-focus && $!focus && $!focus !=== self {
        $!focus.dispatch: $ev
    }
    else {
        nextsame
    }
}

multi method handle-event(::?ROLE:D: Event::ZOrder::Child:D $ev) {
    my $child = $ev.child;
    self.trace: "Focusable Child ZOrder on ", $child, :event;
    if $!focus-topmost && $child ~~ ::?ROLE {
        self.trace: "Updating focus";
        self.cmd-focus-update;
    }
    nextsame
}

multi method handle-event(::?ROLE:D: Event::Focus::In:D $ev) {
    self.trace: "set myself into focus by ", $ev;
    $!in-focus = True;
    .dispatch: Event::Focus::In with $!focus;
    self.invalidate;
    self.cmd-redraw;
    nextsame
}

multi method handle-event(::?ROLE:D: Event::Focus::Out:D $ev) {
    # Desktop doesn't lose focus
    self.trace: "Focus out event: ", $ev;
    with $.parent {
        self.trace: "remove focus from myself";
        $!in-focus = False;
        with $!focus {
            .dispatch: Event::Focus::Out;
        }
        self.invalidate;
        self.cmd-redraw;
    }
    nextsame
}

### Command handlers ###

method cmd-addchild(::?ROLE:D: $child, |) {
    callsame;
    self.trace: "Focusable handles attach of ", $child;
    if $child ~~ ::?ROLE {
        # If child has reparented it might still preserve its focused status. Reset it.
        if $child.in-focus {
            # By default a child is added unfocused. $.focus-topmost controls if it will gain the focus later.
            self.trace: "Unfocusing child ", $child.name;
            $child.dispatch: Event::Focus::Out;
        }
    }
}

method cmd-removechild(::?ROLE:D: $child, |) {
    callsame;
    if $child === $!focus {
        $!focus = Nil;
        if $!focus-topmost {
            self.cmd-focus-update;
        }
    }
}

method !focus-to($child) {
    return if $!focus eqv $child;
    with $!focus {
        self.trace: "Report focus lose";
        .dispatch: Event::Focus::Lost;
        .dispatch: Event::Focus::Out if $!in-focus;
    }
    $!focus = $child;
    with $child {
        self.trace: "Report focus take";
        .dispatch: Event::Focus::Take;
        .dispatch: Event::Focus::In if $!in-focus;
    }
}

method cmd-focus-update(::?ROLE:D:) {
    return if self.closed;
    my $topmost;
    self.for-children: :reverse, -> $child {
        if $child ~~ ::?ROLE && !$child.closed {
            $topmost = $child;
            last
        }
    }
    self.trace: "Current topmost child is: ", $topmost // '*none*', " vs. focused ", $!focus // '*none*';
    # Only if focus changed
    self!focus-to($topmost);
}

method cmd-focus-request(::?ROLE:D $child) {
    self.trace: "Requested focus for ", $child;
    self.is-my-child: $child;
    self!focus-to($child);
}

### Command senders ###

# Set $child as focused on parent.
method update-focus(::?ROLE:D:) {
    self.send-command: Event::Cmd::Focus::Update
}

method focus {
    .send-command: Event::Cmd::Focus::Request, self with $.parent;
}

### Utility methods ###

method attr {
    return $!focused-attr if $!focused-attr && $!in-focus;
    nextsame
}

method fg {
    return $!focused-attr.fg if $!focused-attr && $!in-focus;
    nextsame
}

method bg {
    return $!focused-attr.bg if $!focused-attr && $!in-focus;
    nextsame
}

method bg-pattern {
    return $!focused-attr.pattern if $!focused-attr && $!in-focus;
    nextsame
}
