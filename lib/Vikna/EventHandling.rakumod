use v6;
unit role Vikna::EventHandling;

use Vikna::Events;

my class EvSupplier is Supplier {
    method subscribe(&code) {
        self.Supply.tap: &code
    }
}

has $.ev = EvSupplier.new;

multi method dispatch(Vikna::Event:D $ev) {
    $!ev.emit: $ev
}

multi method dispatch(Vikna::Event:U \EvType, *%params) {
    $!ev.emit: EvType.new: :origin( self ), |%params
}
