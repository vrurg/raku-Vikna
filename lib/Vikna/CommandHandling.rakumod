use v6.e.PREVIEW;

unit role Vikna::CommandHandling;

use Vikna::Events;
use Vikna::X;

multi method event(::?CLASS:D: Event::Command:D $ev) {
    # Only process commands sent by ourselves. Protect from stray events.
    $.throw: X::Event::CommandOrigin, :$ev, dest => self
        unless $ev.origin === self;
    # To form a default command name everything up to and including Event in event's class FQN is stripped off. The
    # remaining elements are lowercased and joined with a dash:
    # Vikna::Event::Cmd::Name -> cmd-name
    # Vikna::TextScroll::Event::SomeCmd::Name -> somecmd-name
    my $cmd-name = $ev.^can("cmd")
                    ?? $ev.cmd
                    !! $ev.^name
                          .split( '::' )
                          .grep({ "Event" ^ff * })
                          .map( *.lc )
                          .join( '-' );
    $.trace: "COMMAND EVENT: ", $cmd-name;
    if self.^can($cmd-name) {
        $ev.complete( self."$cmd-name"( |$ev.args ) );
        CATCH {
            default {
                note "Failed keeping completed promise on $ev: ", ~($ev.completed-at // "*no idea where*");
                $.trace: "EVENT {$ev} HAS BEEN COMPLETED AT ", ~($ev.completed-at // "*no idea where*"),
                        "\n", .message ~ .backtrace,
                        :error;
                $.panic: $_
            }
        }
    }
    elsif self.^can('CMD-FALLBACK') {
        $.trace: "PASSING TO CMD-FALLBACK";
        $ev.complete( self.CMD-FALLBACK($ev) );
    }
}
