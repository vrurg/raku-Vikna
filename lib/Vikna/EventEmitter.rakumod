use v6.e.PREVIEW;
use Vikna::Object;

unit role Vikna::EventEmitter;

use Vikna::Events;

has Supplier:D $!ev-supplier handles <Supply> .= new;

proto method post-event(Event, |) {*}
multi method post-event(Event:U \evType, *%p) {
    CATCH {
        default {
            note "FAILED TO CREATE EVENT ", evType.^name, "\n", %p.raku;
            .rethrow;
        }
    }
    $.post-event: evType.new( :origin(self), :dispatcher(self), |%p );
}
multi method post-event(Event:D $ev) {
    $!ev-supplier.emit: $ev;
    $ev
}

method shutdown {
    $!ev-supplier.done;
}

method panic($cause) {
    $!ev-supplier.quit($cause);
}
