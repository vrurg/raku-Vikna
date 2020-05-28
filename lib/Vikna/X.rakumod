use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::X> - collection of exception classes

=DESCRIPTION

Please, consult the source for more information about an exception than is provided by this documentation. Exceptions
are far from being stabilized and documenting all of them doesn't make big sense yet.

=head1 Class C<X::Base>

Is L<C<Exception>|https://docs.raku.org/type/Exception>. The base class of all Vikna exceptions. Define a single required attribute C<$.obj> which points to
the object which method thrown the exception.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,
L<C<Vikna::Point>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Point.md>,
L<C<Vikna::Rect>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Rect.md>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

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

class X::NoChild is X::Base is export {
    has Any:D $.child is required;
    method message {
        "Child " ~ $!child.WHICH ~ " doesn't exists on parent " ~ $.obj.WHICH
    }
}

class X::Canvas::BadViewport is X::Base does X::Geometry is export {
    method message {
        callsame() ~ " Bad viewport position, possibly out of range: " ~ self.X::Geometry::Str
    }
}

class X::BadColor is X::Base is export {
    has Str $.which;
    has $.color;

    method message {
        my $which = $!which ?? " " ~ $!which !! "";
        "Bad$which color: '" ~ $!color ~ "'"
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
        "Can't send " ~ $.ev.^name ~ ": event handling is stopped on " ~ $.obj.name
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

class X::OverUnblock is X::Base {
    has Int:D $.count is required;
    has Str:D $.what is required;
    method message {
        "Over-unblocked $!what: " ~ abs($!count) ~ " too many. Check your balance of block/unblock calls"
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

class X::PosOwner::Exists does X::Eventish {
    method message {
        "Cannot set owner for pointer event of type '"
        ~ $.ev.kind
        ~ "': it is still owned by another widget"
    }
}

class X::Color::BadChanType is X::Comp {
    has $.expected;
    has $.got;
    method message {
        "Expected channel value of type $!expected but got $!got"
    }
}

# Can't be X::Base because is used by low-level subs
class X::CAttr::UnknownStyle is Exception {
    has Str:D $.style is required;
    method message {
        "Unknown style name '$!style'"
    }
}
