use v6;
use Terminal::Print;
use Term::UI::Widget;
use Term::UI::Desktop;
use Log::Async;
unit class Term::UI::App is export;

my ::?CLASS $app;

has Terminal::Print:D $.screen = Terminal::Print.new;
has Term::UI::Desktop $.desktop;
has Log::Async $.logger;

method new(|) {
    $app //= callsame;
}

submethod TWEAK(|) {
    $!logger = Log::Async.new;
    $!logger.send-to('./term-ui.log', :level(*));
    $!desktop = self.new-desktop;
}

method debug(*@args) {
    $.logger.log(msg => "[" ~ $*THREAD.id.fmt("%5d") ~ "] " ~ @args.join, :level(DEBUG), :frame(callframe(1)));
}

method new-desktop {
    $!screen.root-widget:
        Term::UI::Desktop.new-from-grid:
            $!screen.grid-object( '.default' ),
            :app( self ),
            :auto-clear;
}

multi method run(::?CLASS:U: |c) {
    self.new.run(|c);
}

multi method run(::?CLASS:D:) {
    my $*TERM-UI-APP = self;
    $!screen.initialize-screen;
    self.main;
    LEAVE $!screen.shutdown-screen;
}
