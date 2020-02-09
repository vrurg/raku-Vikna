use v6.e.PREVIEW;
use Vikna::Object;

unit role Vikna::EventEmitter;

use Vikna::Events;

has Supplier:D $!ev-supplier handles <Supply> .= new;

multi method post-event(Event:U \evtype, |c) {
    CATCH {
        default {
            note "FAILED TO CREATE EVENT ", evtype.^name, "\n", c.perl;
            .rethrow;
        }
    }
    $.post-event: evtype.new( :origin(self), :dispatcher(self), |c );
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
