use v6.e.PREVIEW;
use Vikna::Object;
unit class Vikna::App;
also is Vikna::Object;

use Terminal::Print;
use Vikna::Widget;
use Vikna::Desktop;
use Vikna::Screen;
use Vikna::Events;
use Vikna::OS;
use Vikna::Tracer;
use AttrX::Mooish;

my ::?CLASS $app;

#| Named parameters to be passed to a screen driver constructor
has %.screen-params;
has Vikna::Screen $.screen is mooish(:lazy);
has Vikna::Desktop $.desktop is mooish(:lazy);
has Vikna::Tracer $.tracer is mooish(:lazy);
#| Tracer database name
has Str $.tracer-name is mooish(:lazy);
has Bool:D $.debugging = False;
has Vikna::OS $.os is mooish(:lazy) handles <inputs>;
#| Named parameters for $.desktop constructor
has %.desktop-profile;

method new(|) {
    $app //= callsame;
}

method profile-default {
    desktop-profile => %(
        :name<Desktop>,
        attr => {
            :pattern<.>,
        },
        :!auto-clear,
        # :bg<black>,
        # :inv-mark-color<00,00,50>,
    )
}

my %os2mod =
    darwin  => 'unix',
    freebsd => 'unix',
    linux   => 'unix';

method build-os {
    self.throw: X::OS::Unsupported, os => $*VM.osname
        unless %os2mod{$*VM.osname}:exists;

    my $os-module = 'Vikna::OS::' ~ %os2mod{$*VM.osname};

    require ::($os-module);
    self.create: ::($os-module);
}

method build-screen {
    $.os.screen.init: |%!screen-params;
    $.os.screen
}

method build-tracer-name {
    .subst(":", "_", :g) ~ ".sqlite" with self.^name;
}

method build-tracer {
    # note "CREATING TRACER DB ", $db-name, " with session ", self.^name;
    Vikna::Tracer.new: :db-name( $.tracer-name ), :session-name( self.^name ), :!to-err;
}

method build-desktop {
    self.create:
        Vikna::Desktop,
        |%!desktop-profile,
        :geom($.screen.geom.clone),
        ;
}

proto method trace(|) {
    return unless $!debugging;
    {*}
}
multi method trace(&code, *%c) {
    self.trace: |&code(), |%c
}
multi method trace(*@args, :$obj = self, *%c) {
    my $message = @args.join;
    for <phase debug event error> { # predefined classes
        %c<class> = $_ if %c{$_}:delete;
    }
    $!tracer.record(:object-id($obj.?name // ~$obj.WHICH), :$message, |%c)
}

multi method run(::?CLASS:U: |c) {
    self.new.run(|c);
}

multi method run(::?CLASS:D: |c) {
    self.flow: :sync, :name('MAIN'), {
        PROCESS::<$VIKNA-APP> = self;
        self.trace: "Starting app" ~ self.^name, obj => self, :phase;
        $!desktop.dispatch: Event::Init;
        $!desktop.dispatch: Event::Focus::In;
        $!desktop.invalidate;
        $!desktop.redraw;
        $!desktop.sync-events: :transitive;
        self.trace: "PASSING TO MAIN", :phase;
        $.main(|c);
        self.trace: "MAIN IS DONE", :phase;
        $.desktop.sync-events(:transitive) unless $.desktop.closed;
        self.trace: "CLOSING DESKTOP", :phase;
        await $.desktop.dismissed;
        self.trace: "APP DONE!", :phase;

        LEAVE {
            # $!screen.shutdown;
            $!tracer.shutdown if $!debugging;
        }
        CATCH {
            default {
                note .message, ~.backtrace;
                self.trace: .message, .backtrace, :error;
                .rethrow;
            }
        }
    }
}

method create(Mu \type, |c) {
    type.new( :app(self), |c );
}

my $panic-lock = Lock.new;
method panic($cause, :$object?) {
    $panic-lock.protect: {
        CATCH {
            default {
                note "APP PANIC PANICED: ", .message, ~.backtrace;
                exit 2;
            }
        }
        my $obj-id = $object.?name // $object.WHICH;
        my $msg = "Caused by {$obj-id}\n" ~ $cause ~ $cause.backtrace
                    ~ "\nPanic path:\n" ~ Backtrace.new;
        self.trace: "APP PANIC! ", $msg, :error;
        note "===APP PANIC!=== ", $msg;
        $.desktop.panic-shutdown($cause);
        $!tracer.shutdown;
        exit 1;
    }
}

### Utility methods ###

method profile-config(\type, $name?) {
    %()
}
