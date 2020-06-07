use v6.e.PREVIEW;
unit package Vikna;

use Vikna::Rect;
use Vikna::Point;
use Vikna::Child;
use Vikna::Parent;
use Vikna::Dev::Kbd;
use Vikna::CAttr;
use Vikna::X;
use AttrX::Mooish;

my atomicint $sequence = -1;

# PrioImmediate must always be the highest level of all.
enum EventPriority is export ( PrioIdle => 0, |<PrioDefault PrioCommand PrioReleased PrioOut PrioIn PrioImmediate>);

class Event is export {
    has Int $.id is built(False);
    has $.origin is mooish(:lazy);  # Originating object.
    has $.dispatcher is required;   # Dispatching object. Changes on re-dispatch.
    has Bool:D $.cleared = False;
    has EventPriority $.priority is mooish(:lazy<default-priority>);
    has Set $.tags;

    method default-priority { PrioDefault }

    submethod TWEAK {
        self!set-id;
        without $!tags {
            my $cur-event = $*VIKNA-CURRENT-EVENT;
            my $event-tag = $*VIKNA-EVENT-TAG;
            with $*VIKNA-FLOW {
                $cur-event //= .<$*VIKNA-CURRENT-EVENT>;
                $event-tag //= .<$*VIKNA-EVENT-TAG>;
            }
            $!tags =
                set |(($cur-event && $cur-event.tags.keys) // Empty),
                    |($event-tag // Empty);
        }
    }

    method !set-id {
        $!id = ++⚛$sequence;
    }

    method dup(*%p) {
        my $dup = self.clone: |%p;
        $dup!set-id;
        $dup
    }

    method clear {
        $!cleared = True;
    }

    method build-origin { $!dispatcher }

    method last-id { ⚛$sequence }

    proto method tag(|) {*}
    multi method tag(Set:D $tags) { $!tags ∪= $tags; }
    multi method tag(+@tags)      { $!tags ∪= @tags; }

    proto method untag(|) {*}
    multi method untag(Set:D $tags) { $!tags (-)= $tags; }
    multi method untag(@tags)       { $!tags (-)= @tags }

    # Make a method name from event class name.
    method to-method-name(Str:D $prefix is copy = "" --> Str) {
        $prefix ~= "-" if $prefix && $prefix.substr(* - 1) ne '-';
        $prefix ~ self.^name
                    .split('::')
                    .grep({'Event' ^ff *}) # Skipp up to and including first Event. Support events declared in other modules.
                    .map({.lc})
                    .join("-")
    }

    proto method Str(|) {*}
    multi method Str(::?CLASS:U:) { nextsame }
    multi method Str(::?CLASS:D:) {
        self.^name ~ " #{$!id}:"
                   ~ ($!tags ?? " [" ~ $!tags.keys.join(",") ~ "]" !! "")
                   ~ " orig={$!origin.?name // $!origin.WHICH}"
                   ~ " disp={$!dispatcher.?name // $!dispatcher.WHICH}"
                   ~ ($!cleared ?? " clear" !! "")
    }

    method gist { self.Str }
}

### EVENT CATEGORIES ###

# Quick priority setting

role Event::Prio::Idle     { method default-priority { PrioIdle     } }
role Event::Prio::Default  { method default-priority { PrioDefault  } }
role Event::Prio::Command  { method default-priority { PrioCommand  } }
role Event::Prio::Released { method default-priority { PrioReleased } }
role Event::Prio::In       { method default-priority { PrioIn       } }
role Event::Prio::Out      { method default-priority { PrioOut      } }

# State-transition events.
role Event::Changish[::T \type = Any] {
    has T $.from is required;
    has T $.to   is required;
}

# Events with this role must follow the rules of focused dispatching. See Event::Kbd
role Event::Focusish { }

# Anything related to the order of widgets on parent
role Event::ZOrderish { }

# Events which should be auto-dispatched to children
role Event::Spreadable { }

# Informational events. Usually consequences of actions.
class Event::Informative is Event does Event::Prio::Default { }

# Commanding events like 'move', or 'resize', or 'redraw'
class Event::Command is Event does Event::Prio::Command {
    has Promise:D $.completed .= new;
    has $.completed-at;
    has Capture:D $.args = \();

    method complete($rc) {
        $!completed-at = Backtrace.new(1);
        $.completed.keep($rc);
    }
}

class Event::Input  is Event does Event::Prio::In  { }
class Event::Output is Event does Event::Prio::Out { }

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

# Events bound to any 2D positions. For example, mouse events.
role Event::Positionish {
    has Vikna::Point:D $.at is required handles <x y>;
}

# Events related to directional position pairs. Area scrolling, for example. Or mouse drag start/end.
role Event::Vectorish {
    has Vikna::Point:D $.from is required;
    has Vikna::Point:D $.to is required;
}

# Any event which might result in window moving to the top.
role Event::Pointer::Elevatish { }

# Parent/child relations
role Event::Childish {
    has Vikna::Child:D $.child is required;
}
role Event::Parentish {
    has Vikna::Parent:D $.parent is required;
}
role Event::Relational does Event::Childish does Event::Parentish { }

class Event::Kbd is Event::Input does Event::Focusish {
    has $.raw;  # Raw char code if known
    has $.char;
    has Set:D $.modifiers = set();

    method Str {
        my $str = callsame;
        if $!char.defined {
            my $cord = $!char.ord;
            $str ~= " char: «" ~ ($cord ~~ /<print>/ ?? $!char !! '\x' ~ $cord.base(16)) ~ "»";
        }
        $str
    }
}

# Partial key event, i.e. one which is not considered as key is pressed.
role Event::Kbd::Partial { }
# Complete key press.
role Event::Kbd::Complete { }

class Event::Pointer is Event::Input does Event::Positionish {
    method kind(--> Str:D) {...}
}

class Event::Mouse is Event::Pointer {
    has Int $.button;
    has @.buttons;
    has Set $.modifiers = set();
    has Vikna::Point $.prev; # Previous mouse position. Undef for the first mouse event.

    method dup(*%p) {
        nextwith at => $.at.clone,
                 buttons => [ |@!buttons ],
                 modifiers => $!modifiers.clone,
                 |%p
    }

    method kind( --> Str:D ) { 'mouse' }
}

#### Commands ####

class Event::Cmd::AddChild            is Event::Command { }
class Event::Cmd::AddMember           is Event::Command { }
class Event::Cmd::ChildCanvas         is Event::Command { method default-priority { PrioOut } }
class Event::Cmd::Clear               is Event::Command { }
class Event::Cmd::Close               is Event::Command { }
class Event::Cmd::Focus::Update       is Event::Command { }
class Event::Cmd::Focus::Request      is Event::Command { }
class Event::Cmd::Nop                 is Event::Command { method default-priority { PrioDefault } }
class Event::Cmd::Print::String       is Event::Command { method default-priority { PrioOut } }
class Event::Cmd::Quit                is Event::Command { }
class Event::Cmd::Redraw              is Event::Command { }
class Event::Cmd::Refresh             is Event::Command { method default-priority { PrioReleased } }
class Event::Cmd::RemoveChild         is Event::Command { }
class Event::Cmd::RemoveMember        is Event::Command { }
class Event::Cmd::ScreenPrint         is Event::Command { }
class Event::Cmd::Scroll::By          is Event::Command { }
class Event::Cmd::Scroll::Fit         is Event::Command { }
class Event::Cmd::Scroll::SetArea     is Event::Command { }
class Event::Cmd::Scroll::To          is Event::Command { }
class Event::Cmd::SetAttr             is Event::Command { }
class Event::Cmd::SetBgPattern        is Event::Command { }
class Event::Cmd::SetColor            is Event::Command { }
class Event::Cmd::SetGeom             is Event::Command { }
class Event::Cmd::SetHidden           is Event::Command { }
class Event::Cmd::SetStyle            is Event::Command { }
class Event::Cmd::ScreenGeom          is Event::Command { }
class Event::Cmd::SetText             is Event::Command { }
class Event::Cmd::SetTitle            is Event::Command { }
class Event::Cmd::SetInvisible        is Event::Command { }
class Event::Cmd::TextScroll::AddText is Event::Command { }
class Event::Cmd::To::Top             is Event::Command { }
class Event::Cmd::Update::Positions   is Event::Command { method default-priority { PrioImmediate } }

# Inquiring commands
class Event::Cmd::Inquiry is Event::Command {
    method default-priority { PrioImmediate }
}

class Event::Cmd::Contains is Event::Cmd::Inquiry { }

#### Informative ####

# Normally sent once only. Has to be delivered ASAP to be the first event ever.
class Event::Init  is Event::Informative { method default-priority { PrioImmediate } }
class Event::Ready is Event::Informative { method default-priority { PrioImmediate } }

class Event::Quit is Event::Informative does Event::Spreadable { method default-priority { PrioImmediate } }

class Event::Idle is Event::Informative {
    method default-priority { PrioIdle }
}

# Character attributes has changed
class Event::Changed::Attr does Event::Changish[Vikna::CAttr] is Event::Informative { }
class Event::Changed::Color is Event::Changed::Attr { }
class Event::Changed::Style is Event::Changed::Attr { }

class Event::Changed::Title does Event::Changish[Str] is Event::Informative { }

class Event::Changed::Text does Event::Changish[Str] is Event::Informative { }

class Event::Changed::BgPattern does Event::Changish[Str] is Event::Informative { }

class Event::InitDone     is Event::Informative { }
class Event::Redrawn      is Event::Informative { }
class Event::Flattened    is Event::Informative { }
class Event::Hide         is Event::Informative { }
class Event::Show         is Event::Informative { }
class Event::Visible      is Event::Informative { }
class Event::Invisible    is Event::Informative { }

# Focus::Take is about being potentially in focus.
# Focus::In is about receiving focus and must result in focusing the last child which got Focus::Take
class Event::Focus        is Event::Informative { method default-priority { PrioReleased } }
class Event::Focus::Take  is Event::Focus       { } # Child is focused on parent
class Event::Focus::Lost  is Event::Focus       { } # Child lost focus on parent
class Event::Focus::In    is Event::Focus       { } # Our parent widget is in focus
class Event::Focus::Out   is Event::Focus       { } # Our parent widget is out of focus

class Event::Closing   is Event::Informative { }

class Event::Changed::Geom   is Event::Informative does Event::Transformish { }

class Event::ZOrder::Top    is Event::Informative does Event::ZOrderish { }
class Event::ZOrder::Bottom is Event::Informative does Event::ZOrderish { }
class Event::ZOrder::Middle is Event::Informative does Event::ZOrderish { }
class Event::ZOrder::Child  is Event::Informative does Event::ZOrderish does Event::Childish { }

# Dispatched whenever widget canvas has been flattened into parent
class Event::Updated is Event::Informative {
    # Widget canvas geometry
    has $.geom          is required;
}
# Dispatched when synchronized flattening of a group is about to happen.
class Event::ClockSignal is Event::Informative { }

class Event::Scroll::Position is Event::Informative does Event::Vectorish { }
class Event::Scroll::Area     is Event::Informative does Event::Transformish { }

class Event::TextScroll::BufChange does Event::Changish[Int:D] is Event::Informative { }

class Event::Kbd::Down    is Event::Kbd does Event::Kbd::Partial { }
class Event::Kbd::Up      is Event::Kbd does Event::Kbd::Partial { }
class Event::Kbd::Press   is Event::Kbd does Event::Kbd::Complete { }
class Event::Kbd::Control is Event::Kbd does Event::Kbd::Complete {
    has $.key is required where ControlKeys:D | Str:D;

    method Str {
        callsame() ~ " key(" ~ $!key.^name ~ "): «" ~ $!key ~ "»";
    }
}

class Event::Mouse::Move        is Event::Mouse { }
class Event::Mouse::Button      is Event::Mouse { }
class Event::Mouse::Press       is Event::Mouse::Button { }
class Event::Mouse::Release     is Event::Mouse::Button { }
class Event::Mouse::Click       is Event::Mouse::Button does Event::Pointer::Elevatish { }
class Event::Mouse::DoubleClick is Event::Mouse::Button { }
class Event::Mouse::Drag        is Event::Mouse::Move { }

role Event::Mouse::Transition does Event::Positionish {
    has @.buttons is required;
    has Set:D $.modifiers is required;
}
class Event::Mouse::Enter       does Event::Mouse::Transition is Event::Input { }
class Event::Mouse::Leave       does Event::Mouse::Transition is Event::Input { }

class Event::Pointer::OwnerChange does Event::Changish does Event::Positionish is Event::Input { }

class Event::Button             is Event::Informative   { }
class Event::Button::Down       is Event::Button        { }
class Event::Button::Up         is Event::Button        { }
class Event::Button::Press      is Event::Button        { }
class Event::Button::Ok         is Event::Button::Press { }
class Event::Button::Cancel     is Event::Button::Press { }

class Event::Screen::FocusIn    is Event::Input { }
class Event::Screen::FocusOut   is Event::Input { }
class Event::Screen::PasteStart is Event::Input { }
class Event::Screen::PasteEnd   is Event::Input { }

# Emitted when screen has done an output job.
class Event::Screen::Ready is Event::Informative { }

class Event::Screen::Geom
        is Event::Informative
        does Event::Transformish
        does Event::Spreadable
{
    method default-priority { PrioImmediate }
}

class Event::Attached is Event::Informative does Event::Relational { }
class Event::Detached is Event::Informative does Event::Relational { }
