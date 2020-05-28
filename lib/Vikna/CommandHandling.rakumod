use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::CommandHandling> - role implementing command emission and processing.

=DESCRIPTION

This role unifies processing of C<Event::Command> category of events. A command is the way external code communicate
to a event handling object and this is how I<kick and go> principle is implemented "in flesh".

A command is an event which class is inheriting from C<Event::Command>. It has two distinctive properties: I<completion
status> and I<arguments>.

I<Arguments> is just a capture to invoke a command handler with. I<Completion status> is a L<C<Promise>|https://docs.raku.org/type/Promise>
which is kept with command handler return value.

=head2 Command Handlers

A command handler is a method which would be invoked by event loop flow to react on a command event. For example:

    $widget.move: $x, $y;

results in:

=item C<Event::Cmd::SetGeom> is dispatched with a capture of C<\($x, $y)> form
=item it passes all the usual stages of event dispatching
=item event loop invokes C<cmd-setgeom> method, so that it receives two positionals from the capture above
=item C<Event::Cmd::SetGeom> object is completed with C<cmd-setgeom> result

The method name of an event handler can be defined by the command event class using C<cmd> method which should return
the name. Otherwise method name is formed from the class name by stripping off the C<Event::> namespace prefix. The
rest of the event class name parts are lowercased and joined with C<->. This is how in the example above we get
C<cmd-setgeom> from C<Event::Cmd::SetGeom>. Another example of the transformation is C<Event::Cmd::Scroll::To> becomes
C<cmd-scroll-to>.

If command handler of the given name doesn't exists then C<CMD-FALLBACK> is tried. If found it is invoked with the only
parameter – the command event itself.

No handler for a command event it not an error situation. Such event would be silently ignored.

=METHODS

=head2 C<multi event(Event::Command:D $ev)>

Responsible for implementing the command handling.

=head2 C<multi send-event(Event::Command:U \evType, |args)>
=head2 C<multi send-event(Event::Command:U \evType, Capture:D $args)>
=head2 C<multi send-event(Event::Command:U \evType, Capture:D $args, %params)>

The method is a L<C<Vikna::Event::Handling>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Event/Handling.md>
C<send-event> convenience wrapper. Similarly to C<dispatcher> method, C<send-command> creates an event object and passes
it for event loop handling. The difference is that because a command must always be submitted to the object it is
originated by, C<send-command> bypasses C<route-event> and submits directly into C<send-event> method.

C<args> and C<$args> captures are passed down to the command handle method.

C<%params> is used as event constructor profile.

Returns C<send-event> return value.

=head1 SEE ALSO

L<Vikna|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<Vikna::Manual|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,
L<Vikna::CommandHandling|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/CommandHandling.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

unit role Vikna::CommandHandling;

use Vikna::Events;
use Vikna::X;

multi method event(::?ROLE:D: Event::Command:D $ev) {
    # Only process commands sent by ourselves. Protect from stray events.
    self.throw: X::Event::CommandOrigin, :$ev, dest => self
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
    self.trace: "COMMAND EVENT: ", $cmd-name;
    if self.^can($cmd-name) {
        CATCH {
            default {
                note "Failed keeping completed promise on $ev: ", ~($ev.completed-at // "*no idea where*");
                self.trace: "EVENT {$ev} HAS BEEN COMPLETED AT ", ~($ev.completed-at // "*no idea where*"),
                        "\n", .message ~ .backtrace,
                        :error;
                self.panic: $_
            }
        }
        $ev.complete( self."$cmd-name"( |$ev.args ) );
    }
    elsif self.^can('CMD-FALLBACK') {
        self.trace: "PASSING TO CMD-FALLBACK";
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
    self.trace: "send-command ", evType.^name, " with params: ",
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
