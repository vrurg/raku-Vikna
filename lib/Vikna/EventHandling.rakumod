use v6.e.PREVIEW;
unit role Vikna::EventHandling;

use Vikna::Events;

my class EvSupplier is Supplier {
    method subscribe(&code) {
        start react {
            whenever self.Supply {
                &code($_)
            }
        }
    }
}

has $.events = EvSupplier.new;

multi method dispatch(Vikna::Event:D $ev) {
    $!events.emit: $ev.clone(:origin($ev.dispatcher))
}

multi method dispatch(Vikna::Event:U \EvType, *%params) {
    $!events.emit: self.create(EvType, :dispatcher( self ), |%params )
}
