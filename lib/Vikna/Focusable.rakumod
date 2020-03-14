use v6.e.PREVIEW;

unit role Vikna::Focusable;

use Vikna::Widget;
use Vikna::Events;
use Vikna::CAttr;
use Hash::Merge;

has ::?ROLE $.focus;
has Bool:D $.in-focus = False;

has Vikna::CAttr $.focused-attr;

submethod profile-default {
    focused-attr => {
            # fg => 'black',
            # bg => 'cyan',
            # pattern => ' '
    }
}

submethod profile-checkin(%profile, %, %, %) {
    unless %profile<focused-attr> ~~ Vikna::CAttr {
        my %fa = $_ with %profile<focused-attr>;
        %fa{$_} //= %profile{$_} if $_ for <focused-fg focused-bg focused-pattern>;
        %profile<focused-attr> = %profile<attr>.clone(|%fa);
    }
    %profile<focused-fg focused-bg focused-pattern>:delete;
}

multi method route-event(::?ROLE:D: Event::Focusish:D $ev) is default {
    if $!in-focus && $!focus && $!focus !=== self {
        $!focus.dispatch: $ev
    }
    else {
        nextsame
    }
}

multi method handle-event(::?ROLE:D: Event::ZOrder::Child:D $ev) is default {
    my $child = $ev.child;
    $.trace: "Focusable Child ZOrder on ", $child, :event;
    if $child ~~ ::?ROLE {
        $.trace: "Updating focus";
        $.update-focus;
    }
    nextsame
}

multi method handle-event(::?ROLE:D: Event::Focus::In:D $ev) is default {
    $.trace: "set myself into focus";
    $!in-focus = True;
    .dispatch: Event::Focus::In with $!focus;
    $.invalidate;
    $.redraw;
    nextsame
}

multi method handle-event(::?ROLE:D: Event::Focus::Out:D $ev) is default {
    # Desktop doesn't lose focu s
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

# method cmd-addchild(::?ROLE:D: $child, |) {
#     callsame;
#     $.cmd-focus-update;
# }

method cmd-focus-update(::?ROLE:D:) {
    my $topmost;
    $.for-children: :reverse, -> $child {
        if $child ~~ ::?ROLE {
            $topmost = $child;
            last
        }
    }
    $.trace: "Current topmost child is: ", $topmost // '*none*', " vs. focused ", $!focus // '*none*';
    # Only if focus changed
    unless $!focus eqv $topmost {
        with $!focus {
            $.trace: "Report focus lose";
            .dispatch: Event::Focus::Lost;
            .dispatch: Event::Focus::Out if .in-focus;
        }
        $!focus = $topmost;
        with $topmost {
            $.trace: "Report focus take";
            .dispatch: Event::Focus::Take;
            .dispatch: Event::Focus::In if $!in-focus;
        }
    }
}

### Command senders ###

# Set $child as focused on parent.
method update-focus(::?ROLE:D:) {
    $.send-command: Event::Cmd::Focus::Update
}

### Utility methods ###

method attr {
    $.trace: "focusable attr";
    return $!focused-attr if $!in-focus;
    $.trace: "focusable attr: fallback to default";
    nextsame
}

method fg {
    return $!focused-attr.fg if $!in-focus;
    nextsame
}

method bg {
    return $!focused-attr.bg if $!in-focus;
    nextsame
}

method bg-pattern {
    return $!focused-attr.pattern if $!in-focus;
    nextsame
}
