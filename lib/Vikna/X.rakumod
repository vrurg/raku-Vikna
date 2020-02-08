use v6.e.PREVIEW;
unit module Vikna;
use Vikna::Rect;
use Vikna::Point;

class X::Base is Exception is export {
    has $.obj is required;

    method message {
        "[{$!obj.WHICH}]"
    }
}

role X::Geometry is export {
    has Vikna::Rect $.rect handles <Str>;

    multi method new(*@pos where * == 4, *%c) {
        self.new(rect => Vikna::Rect.new: |@pos, |%c)
    }
    multi method new(|) { nextsame }
}

role X::Eventish is X::Base is export {
    has $.ev is required;
}

role X::Widget is X::Base { }

role X::System is X::Base { }

role X::Input is X::System { }

class X::Canvas::BadViewport is X::Base does X::Geometry is export {
    method message {
        callsame() ~ " Bad viewport position, possibly out of range: " ~ self.X::Geometry::Str
    }
}

class X::BadColor is X::Base is export {
    has $.color;

    method message {
        "Bad color: " ~ $!color
    }
}

class X::Event::ReParent does X::Eventish {
    method message {
        "Re-parent event received which doesn't belong to me"
    }
}

class X::Event::Unsubscribe is X::Base {
    has $.subscription-obj is required;
    method message {
        "Can't unsubscribe from " ~ $!subscription-obj.WHICH ~ " object: {$.obj.WHICH} is not subscribed to it"
    }
}

class X::Event::Stopped does X::Eventish {
    method message {
        "Can't send " ~ $.ev.^name ~ ": event handling is stopped on " ~ $.obj.WHICH
    }
}

class X::Event::Dropped does X::Eventish {
    method message {
        "Attempt to use result of a dropped event " ~ $.ev;
    }
}

class X::Event::CommandOrigin does X::Eventish {
    has Any:D $.dest is required;
    method message {
        "Command event " ~ $.ev.^name
        ~ " was originated by " ~ ($.ev.origin.?name // $.ev.origin.WHICH)
        ~ " but received by " ~ ($!dest.name // $!dest.WHICH)
    }
}

class X::Redraw::OverUnblock is X::Base {
    has $.count is required;
    method message {
        "Over-unblocked redraw: " ~ $!count ~ " too much. Check your balance of block/unblock calls"
    }
}

class X::Input::BadSpecialKey does X::Input {
    has $.key;
    method message {
        "Unknown special key '$!key' received from input"
    }
}

class X::OS::Unsupported is X::System {
    has Str:D $.os is required;
    method message {
        "OS '$!os' is not supported yet"
    }
}

class X::Terminal::NoTERM is X::System {
    method message {
        "No TERM environment variable found, required by screen driver " ~ $.obj.^name
    }
}

class X::Detach::NoParent does X::Widget {
    method message {
        "Widget " ~ $.obj.name ~ " cannot detach, no parent"
    }
}

class X::Widget::DuplicateName does X::Widget {
    has $.parent is required;
    has Str:D $.name is required;
    method message {
        "Child with name `$!name` already exists on " ~ $!parent.name;
    }
}

class X::PChannel::NoData is Exception {
    method message {
        "receive called on empty PChannel"
    }
}

class X::PChannel::ReceiveOnClosed is Exception {
    method message {
        "receive called on closed PChannel"
    }
}

class X::PChannel::SendOnClosed is Exception {
    method message {
        "send called on closed PChannel"
    }
}

### Control exceptions ###
class CX::Event::Last is export {
    has Any:D $.ev is required;
}
