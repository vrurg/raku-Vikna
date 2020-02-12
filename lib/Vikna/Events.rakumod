use v6.e.PREVIEW;
unit package Vikna;

use Vikna::Rect;
use Vikna::Point;
use Vikna::Child;
use Vikna::Parent;
use Vikna::Dev::Kbd;
use AttrX::Mooish;

my atomicint $sequence = -1;

# PrioImmediate must always be the highest level of all.
enum EventPriority is export ( PrioIdle => 0, |<PrioDefault PrioCommand PrioReleased PrioOut PrioIn PrioImmediate>);

role Event is export {
    has Int $.seq is built(False);
    has $.origin is mooish(:lazy);  # Originating object.
    has $.dispatcher is required;   # Dispatching object. Changes on re-dispatch.
    has Bool:D $.cleared = False;
    has EventPriority $.priority is mooish(:lazy);

    method build-priority { ... }

    submethod TWEAK {
        self!set-seq;
    }

    method !set-seq {
        $!seq = ++⚛$sequence;
    }

    method clone {
        my $clone = callsame;
        $clone!set-seq;
        $clone
    }

    method clear {
        $!cleared = True;
    }

    method last {
        require ::(Vikna::Events);
        ::('Vikna::Events::CX::Event::Last').new(:ev(self)).throw
    }

    method build-origin { $!dispatcher }

    proto method Str(|) {*}
    multi method Str(::?ROLE:U:) { self.^name }
    multi method Str(::?ROLE:D:) {
        self.^name ~ " #{$!seq}:"
                   ~ " orig={$!origin.?name // $!origin.WHICH}"
                   ~ " disp={$!dispatcher.?name // $!dispatcher.WHICH}"
    }
}

### EVENT CATEGORIES ###

# Quick priority setting

role Event::Prio::Idle     { method build-priority { PrioIdle     } }
role Event::Prio::Default  { method build-priority { PrioDefault  } }
role Event::Prio::Command  { method build-priority { PrioCommand  } }
role Event::Prio::Released { method build-priority { PrioReleased } }
role Event::Prio::In       { method build-priority { PrioIn       } }
role Event::Prio::Out      { method build-priority { PrioOut      } }

# Informational events. Usually consequences of actions.
role Event::Informative does Event does Event::Prio::Default { }

# Events which should be auto-dispatched to children
role Event::Spreadable { }

# Commanding events like 'move', or 'resize', or 'redraw'
role Event::Command does Event does Event::Prio::Command {
    has Promise:D $.completed .= new;
    has $.completed-at;
    has Capture:D $.args = \();

    method complete($rc) {
        $!completed-at = Backtrace.new(1);
        $.completed.keep($rc);
    }
}

role Event::Input does Event does Event::Prio::In   { }
role Event::Output does Event does Event::Prio::Out { }

### EVENT SUBTYPES ###

# Any geometry event without old state.
role Event::Geomish {
    # Alias `to` for Transformish sugar
    has Vikna::Rect:D $.geom is mooish(:alias<to>) is required;
}

# Widget geometry changes of any kind, including position change
role Event::Transformish does Event::Geomish {
    has Vikna::Rect:D $.from is required;
}

# Non-geometry position changes; for example, scrolling-related
role Event::Positionish {
    has Int $.x;
    has Int $.y;
}
role Event::Positional {
    has Vikna::Point:D $.from is required;
    has Vikna::Point:D $.to is required;
}

# Any color event
role Event::Colorish {
    has $.fg;
    has $.bg;
}

# Color changes of any kind.
role Event::ColorChange does Event::Colorish {
    has $.old-fg;
    has $.old-bg;
}

# Anything related to hold of events.
role Event::Holdish does Event {
    has Event:U $ev-type;
    submethod TWEAK(:$!ev-type) { }
}

# Parent/child relations
role Event::Childish does Event {
    has Vikna::Child:D $.child is required;
}
role Event::Parentish does Event {
    has Vikna::Parent:D $.parent is required;
}
role Event::Relational does Event::Childish does Event::Parentish { }

role Event::Kbd does Event::Input {
    has $.raw;  # Raw char code if known
    has $.char;
    has Set:D $.modifiers = set();
}

role Event::Mouse does Event::Input {
    has Int:D $.x is required;
    has Int:D $.y is required;
    has Int $.button;
    has Set $.buttons;
    has Set $.modifiers = set();

    method new-from(Event::Mouse:D $ev, |c) {
        self.new:
                x => .x,
                y => .y,
                buttons => .buttons.clone,
                modifiers => .modifiers.clone,
                dispatcher => .dispatcher,
                origin => .origin,
                |c
            with $ev;
    }
}

#### Commands ####

class Event::Cmd::AddChild            does Event::Command { }
class Event::Cmd::AddMember           does Event::Command { }
class Event::Cmd::ChildCanvas         does Event::Command { }
class Event::Cmd::Clear               does Event::Command { }
class Event::Cmd::Close               does Event::Command { }
class Event::Cmd::Quit                does Event::Command { }
class Event::Cmd::Nop                 does Event::Command { }
class Event::Cmd::Redraw              does Event::Command { }
class Event::Cmd::RemoveChild         does Event::Command { }
class Event::Cmd::RemoveMember        does Event::Command { }
class Event::Cmd::ScreenPrint         does Event::Command { }
class Event::Cmd::Scroll::By          does Event::Command { }
class Event::Cmd::Scroll::Fit         does Event::Command { }
class Event::Cmd::Scroll::SetArea     does Event::Command { }
class Event::Cmd::Scroll::To          does Event::Command { }
class Event::Cmd::SetBgPattern        does Event::Command { }
class Event::Cmd::SetColor            does Event::Command { }
class Event::Cmd::SetHidden           does Event::Command { }
class Event::Cmd::SetGeom             does Event::Command { }
class Event::Cmd::ScreenGeom          does Event::Command { }
class Event::Cmd::SetText             does Event::Command { }
class Event::Cmd::SetTitle            does Event::Command { }
class Event::Cmd::SetInvisible        does Event::Command { }
class Event::Cmd::TextScroll::AddText does Event::Command { }

#### Informative ####

# Normally sent once only. Has to be delivered ASAP to be the first event ever.
class Event::Init does Event::Informative { method priority { PrioImmediate } }

class Event::Quit does Event::Informative does Event::Spreadable { method priority { PrioImmediate } }

class Event::Idle does Event::Informative {
    method build-priority { PrioIdle }
}

class Event::Changed::Title does Event::Informative {
    has $.old-title;
    has $.title;
}

class Event::Changed::Text does Event::Informative {
    has $.old-text;
    has $.text;
}

class Event::Changed::BgPattern does Event::Informative {
    has $.old-bg-pattern;
    has $.bg-pattern;
}

class Event::Hide      does Event::Informative { }
class Event::Show      does Event::Informative { }
class Event::Visible   does Event::Informative { }
class Event::Invisible does Event::Informative { }

class Event::Closing   does Event::Informative { }

class Event::WidgetColor does Event::Informative does Event::ColorChange { }

class Event::Changed::Geom does Event::Informative does Event::Transformish { }

# Dispatched whenever widget content might have changed.
class Event::Updated does Event::Informative {
    has $.geom          is required; # Widget geometry at the point of time when the event was dispatched.
}

class Event::Scroll::Position does Event::Informative does Event::Positional { }
class Event::Scroll::Area does Event::Informative does Event::Transformish { }

class Event::TextScroll::BufChange does Event::Informative {
    has Int:D $.old-size is required;
    has Int:D $.size is required;
}

class Event::Kbd::Down    does Event::Kbd { }
class Event::Kbd::Up      does Event::Kbd { }
class Event::Kbd::Press   does Event::Kbd { }
class Event::Kbd::Control is Event::Kbd::Press {
    has $.key is required where ControlKeys:D | Str:D;
}

class Event::Mouse::Move        does Event::Mouse { }
class Event::Mouse::Button      does Event::Mouse { }
class Event::Mouse::Press       is Event::Mouse::Button { }
class Event::Mouse::Release     is Event::Mouse::Button { }
class Event::Mouse::Click       is Event::Mouse::Button { }
class Event::Mouse::DoubleClick is Event::Mouse::Button { }
class Event::Mouse::Drag        is Event::Mouse::Move { }

class Event::FocusIn    does Event::Input { }
class Event::FocusOut   does Event::Input { }
class Event::PasteStart does Event::Input { }
class Event::PasteEnd   does Event::Input { }

# Emitted when screen has done an output job.
class Event::Screen::Ready does Event::Informative { }

class Event::Screen::Geom
        does Event::Informative
        does Event::Transformish
        does Event::Spreadable
{
    method build-priority { PrioOut }
}

class Event::Attached does Event::Informative does Event::Relational { }
class Event::Detached does Event::Informative does Event::Relational { }
