use v6;
unit role Term::UI::EventHandling;

use Term::UI::Events;

my class EvSupplier is Supplier {
    method subscribe(&code) {
        self.Supply.tap: &code
    }
}

has $.ev = EvSupplier.new;

multi method dispatch(Term::UI::Event:D $ev) {
    $!ev.emit: $ev
}

multi method dispatch(Term::UI::Event:U \EvType, *%params) {
    $!ev.emit: EvType.new: :origin( self ), |%params
}
