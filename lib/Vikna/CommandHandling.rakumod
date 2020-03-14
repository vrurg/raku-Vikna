use v6.e.PREVIEW;

unit role Vikna::CommandHandling;

use Vikna::Events;
use Vikna::X;

multi method event(::?ROLE:D: Event::Command:D $ev) {
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
        CATCH {
            default {
                note "Failed keeping completed promise on $ev: ", ~($ev.completed-at // "*no idea where*");
                $.trace: "EVENT {$ev} HAS BEEN COMPLETED AT ", ~($ev.completed-at // "*no idea where*"),
                        "\n", .message ~ .backtrace,
                        :error;
                $.panic: $_
            }
        }
        $ev.complete( self."$cmd-name"( |$ev.args ) );
    }
    elsif self.^can('CMD-FALLBACK') {
        $.trace: "PASSING TO CMD-FALLBACK";
        $ev.complete( self.CMD-FALLBACK($ev) );
    }
}

proto method send-command(Event::Command $, |) {*}
multi method send-command(Event::Command:U \evType, |args) {
    self.send-command: evType, args, %()
}
multi method send-command(Event::Command:U \evType, Capture:D $args) {
    self.send-command: evType, $args, %()
}
multi method send-command(Event::Command:U \evType, Capture:D $args, %params) {
    $.trace: "send-command ", evType.^name, " with params: ",
                %params.map( { .key ~ " => " ~ .value } ).join("\n");
    CATCH {
        when X::Event::Stopped {
            .ev.completed.break($_);
            return .ev
        }
        default {
            .rethrow;
        }
    }
    self.send-event: evType.new(
                        :origin(self),
                        :dispatcher(self),
                        :$args,
                        |%params
                    )
}
