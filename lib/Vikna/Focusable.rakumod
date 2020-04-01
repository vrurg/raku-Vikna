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
    $.trace: "Focusable Child ZOrder on ", $child, :event;
    if $!focus-topmost && $child ~~ ::?ROLE {
        $.trace: "Updating focus";
        $.update-focus;
    }
    nextsame
}

multi method handle-event(::?ROLE:D: Event::Focus::In:D $ev) {
    $.trace: "set myself into focus by ", $ev;
    $!in-focus = True;
    .dispatch: Event::Focus::In with $!focus;
    $.invalidate;
    $.redraw;
    nextsame
}

multi method handle-event(::?ROLE:D: Event::Focus::Out:D $ev) {
    # Desktop doesn't lose focu s
    $.trace: "Focus out event: ", $ev;
    with $.parent {
        $.trace: "remove focus from myself";
        $!in-focus = False;
        with $!focus {
            .dispatch: Event::Focus::Out;
        }
        $.invalidate;
        $.redraw;
    }
    nextsame
}

### Command handlers ###

method cmd-addchild(::?ROLE:D: $child, |) {
    callsame;
    $.trace: "Focusable handles attach of ", $child;
    if $child ~~ ::?ROLE {
        # If child has reparented it might still preserve its focused status. Reset it.
        if $child.in-focus {
            # By default a child is added unfocused. $.focus-topmost controls if it will gain the focus later.
            $.trace: "Unfocusing child ", $child.name;
            $child.dispatch: Event::Focus::Out;
        }
    }
}

method cmd-removechild(::?ROLE:D: $child, |) {
    callsame;
    if $child === $!focus {
        $!focus = Nil;
        if $!focus-topmost {
            $.update-focus;
        }
    }
}

method !focus-to($child) {
    return if $!focus eqv $child;
    with $!focus {
        $.trace: "Report focus lose";
        .dispatch: Event::Focus::Lost;
        .dispatch: Event::Focus::Out if .in-focus;
    }
    $!focus = $child;
    with $child {
        $.trace: "Report focus take";
        .dispatch: Event::Focus::Take;
        .dispatch: Event::Focus::In if $!in-focus;
    }
}

method cmd-focus-update(::?ROLE:D:) {
    return if $.closed;
    my $topmost;
    $.for-children: :reverse, -> $child {
        if $child ~~ ::?ROLE {
            $topmost = $child;
            last
        }
    }
    $.trace: "Current topmost child is: ", $topmost // '*none*', " vs. focused ", $!focus // '*none*';
    # Only if focus changed
    self!focus-to($topmost);
}

method cmd-focus-request(::?ROLE:D $child) {
    $.trace: "Requested focus for ", $child;
    $.is-my-child: $child;
    self!focus-to($child);
}

### Command senders ###

# Set $child as focused on parent.
method update-focus(::?ROLE:D:) {
    $.send-command: Event::Cmd::Focus::Update
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
