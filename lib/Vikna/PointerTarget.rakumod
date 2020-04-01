use v6.e.PREVIEW;

unit role Vikna::PointerTarget;

use Vikna::Widget;
use Vikna::Events;

my class Event::Cmd::ClearPointerOwner is Event::Command { }

has ::?ROLE:D %!pointer-owners;
has Lock:D $!po-lock .= new;

multi method route-event(::?ROLE:D: Event::Pointer:D $ev, *%) {
    $.trace: "Routing pointer event ", $ev, :event;
    my $new-owner;
    $.for-children: :reverse, -> $child {
        next unless $child ~~ ::?ROLE;
        if $child.abs-viewport.contains($ev.at) {
            $new-owner = $child;
            last;
        }
    };

    # Handle the event myself if no new pointer owner found.
    my $old-owner = $.pointer-owner($ev);
    unless $new-owner {
        $.trace: "Handle the event myself", :event;
        .?pointer-leave($ev) with $old-owner;
        $.pointer-owner: $ev, :delete;
        nextsame
    }

    # A child claims the event. See if it's not an owner already.
    $.trace: "Changing owner? from ", ($old-owner // '*nobody*'), " to ", $new-owner, " for ", $ev, :event;
    unless $old-owner eqv $new-owner {
        $old-owner.?pointer-leave: $ev if $old-owner;
        $.pointer-owner: $ev, $new-owner;
        $new-owner.?pointer-enter: $ev;
        $.dispatch: Event::Pointer::OwnerChange, :from($old-owner), :to($new-owner), at => $ev.at;
    }
    $.trace: "Dispatching via the new owner ", $new-owner, :event;
    $new-owner.dispatch: $ev;
}

### Event handlers ###

### Utility methods ###

# Enter/leave handlers for pointer events supporting this kind of event.
proto method pointer-enter(::?ROLE:D: Event::Pointer:D $, |) {*}
multi method pointer-enter(Event::Mouse:D $ev) {
    $.send-event: Event::Mouse::Enter.new(
                    origin => self,
                    dispatcher => self,
                    at => $ev.at,
                    buttons => $ev.buttons,
                    modifiers => $ev.modifiers,
                );
}

proto method pointer-leave(::?ROLE:D: Event::Pointer:D $, |) {*}
multi method pointer-leave(Event::Mouse:D $ev) {
    $.trace: "Mouse leave, current po: ", $.pointer-owner($ev) // '*undef*', :event;
    $.send-command: Event::Cmd::ClearPointerOwner, $ev.dup;
}

# Supporting methods for pointer owners handling.
proto method pointer-owner(::?ROLE:D: |) {*}
multi method pointer-owner(Event:D $ev, |c) {
    self.pointer-owner($ev.kind, |c);
}
multi method pointer-owner(Str:D $kind, ::?ROLE:D $widget) {
    $!po-lock.protect: {
        %!pointer-owners{$kind} = $widget;
    }
}
multi method pointer-owner(Str:D $kind) {
    $!po-lock.protect: {
        %!pointer-owners{$kind}
    }
}
multi method pointer-owner(Str:D $kind, :$delete! where ?*) {
    $!po-lock.protect: {
        %!pointer-owners{$kind}:delete
    }
}

proto method is-pointer-owner(::?ROLE:D: |) {*}
multi method is-pointer-onwer(Event:D $ev, |c) {
    $.pointer-owner($ev.kind, |c)
}
multi method is-pointer-owner(Str:D $kind, $candidate) {
    $!po-lock.protect: {
        %!pointer-owners{$kind} eqv $candidate
    }
}

### Event handlers ###

### Command handlers ###

method cmd-clearpointerowner(Event:D $ev) {
    my $po = self;
    while $po {
        $po.dispatch: Event::Mouse::Leave,
                        at => $ev.at,
                        buttons => $ev.buttons,
                        modifiers => $ev.modifiers,
                        ;
        $po = $po.pointer-owner: $ev, :delete;
    }
}
