use v6.e.PREVIEW;
unit class Vikna::App;

use Terminal::Print;
use Vikna::Widget;
use Vikna::Desktop;
use Vikna::Screen;
use Log::Async;
use AttrX::Mooish;

my ::?CLASS $app;

#| Named parameters to be passed to a screen driver constructor
has %.screen-params;
has Vikna::Screen $.screen is mooish(:lazy);
has Vikna::Desktop $.desktop is mooish(:lazy, :clearer, :predicate);
has Log::Async $.logger is mooish(:lazy);

method new(|) {
    $app //= callsame;
}

method build-logger {
    my $l = Log::Async.new;
    my $log-name = .subst(":", "_", :g) with self.^name;
    $l.send-to('./' ~ $log-name ~ '.log', :level(*));
    $l
}

method build-screen {
    if $*VM.osname ~~ /:i mswin/ {
        die $*VM.osname ~ " is unsupported yet"
    }
    elsif %*ENV<TERM>:exists {
        use Vikna::Screen::ANSI;
        Vikna::Screen::ANSI.new: |%!screen-params
    }
    else {
        die $*VM.osname ~ " is not Windows but neither I see TERM environment variable"
    }
}

method build-desktop {
    self.create: Vikna::Desktop, :geom($.screen.geom.clone), :bg-pattern<.>;
}

method debug(*@args) {
    $!logger.log(msg => "[" ~ $*THREAD.id.fmt("%5d") ~ "] " ~ @args.join, :level(DEBUG), :frame(callframe(1)));
}

multi method run(::?CLASS:U: |c) {
    self.new.run(|c);
}

multi method run(::?CLASS:D:) {
    my $*VIKNA-APP = self;
    $!screen.init;
    self.main;
    LEAVE $!screen.shutdown;
}

method create(Mu \type, |c) {
    type.new( :app(self), |c );
}
