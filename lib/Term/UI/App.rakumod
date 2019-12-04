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
    $!desktop = self.new-desktop;
    $!logger = Log::Async.new;
    $!logger.send-to('./term-ui.log', :level(*));
    signal(SIGWINCH).tap: { self.on-screen-resize }
}

method debug(*@args) {
    $.logger.log(msg => @args.join, :level(DEBUG), :frame(callframe(1)));
}

method new-desktop {
    $!screen.root-widget: Term::UI::Desktop.new-from-grid: $!screen.grid-object('.default'), :app(self), :auto-clear;
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

method on-screen-resize {
    $!screen.setup(:reset);
    $!desktop.on-screen-resize;
}
