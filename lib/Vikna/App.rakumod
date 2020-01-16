use v6.e.PREVIEW;
use Vikna::Object;
unit class Vikna::App;
also is Vikna::Object;

use Terminal::Print;
use Vikna::Widget;
use Vikna::Desktop;
use Vikna::Screen;
use Vikna::Tracer;
use AttrX::Mooish;

my ::?CLASS $app;

#| Named parameters to be passed to a screen driver constructor
has %.screen-params;
has Vikna::Screen $.screen is mooish(:lazy);
has Vikna::Desktop $.desktop is mooish(:lazy, :clearer, :predicate);
has Vikna::Tracer $.tracer is mooish(:lazy);
has Bool:D $.debugging = False;

method new(|) {
    $app //= callsame;
}

method build-tracer {
    my $db-name = .subst(":", "_", :g) ~ ".sqlite" with self.^name;
    # note "CREATING TRACER DB ", $db-name, " with session ", self.^name;
    Vikna::Tracer.new: :$db-name, :session-name( self.^name ), :!to-err;
}

method build-screen {
    if $*VM.osname ~~ /:i mswin/ {
        die $*VM.osname ~ " is unsupported yet"
    }
    elsif %*ENV<TERM>:exists {
        use Vikna::Screen::ANSI;
        $.create: Vikna::Screen::ANSI, |%!screen-params
    }
    else {
        die $*VM.osname ~ " is not Windows but neither I see TERM environment variable"
    }
}

method build-desktop {
    self.create: Vikna::Desktop,
                    :geom($.screen.geom.clone),
                    :bg-pattern<.>,
                    :!auto-clear;
}

method trace(*@args, :$obj = self, *%c) {
    return unless $!debugging;
    my $message = @args.join;
    for <phase debug event error> { # predefined classes
        %c<class> = $_ if %c{$_}:delete;
    }
    $!tracer.record(:object-id(~$obj.WHICH), :$message, |%c);
}

multi method run(::?CLASS:U: |c) {
    self.new.run(|c);
}

multi method run(::?CLASS:D:) {
    $.flow: :sync, :name('MAIN'), {
        PROCESS::<$VIKNA-APP> = self;
        $.trace: "Starting app" ~ self.^name, obj => self, :phase;
        $!screen.init;
        $!desktop.invalidate;
        $!desktop.redraw;
        $!desktop.sync-events: :transitive;
        $.trace: "PASSING TO MAIN", :phase;
        $.main;
        $.trace: "MAIN IS DONE", :phase;
        $.desktop.sync-events(:transitive);
        $.trace: "CLOSING DESKTOP", :phase;
        await $.desktop.close.completed;
        $.trace: "APP DONE!", :phase;

        LEAVE {
            $!screen.shutdown;
            $!tracer.shutdown if $!debugging;
        }
        CATCH {
            default {
                note .message, ~.backtrace;
                $.trace: .message, .backtrace, :error;
                .rethrow;
            }
        }
    }
}

method create(Mu \type, |c) {
    # note "APP CREATE: ", type.^name, " ", c.perl;
    type.new( :app(self), |c );
}
