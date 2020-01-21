use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Label;
also is Vikna::Widget;

use Vikna::Events;

has Str:D $.text is required;
has Str:D $.l-pad = ' ';
has Str:D $.r-pad = ' ';

method new(|c) {
    nextwith :bg-pattern(' '), |c
}

### Command handlers ###
method cmd-settext(Str:D $text) {
    my $old-text = $!text;
    $!text = $text;
    self.dispatch: Event::Changed::Text, :$old-text, :$text;
    self.invalidate;
    self.redraw;
}

### Command senders ###
method set_text(::?CLASS:D: Str:D $text) {
    self.send-command: Event::Cmd::SetText, $text;
}

### Utility methods ###
method draw( :$canvas ) {
    $.draw-background: :$canvas;
    my @lines = $!text.split: /\n/;
    my $row = 0;
    for @lines -> $line {
        $canvas.imprint: 0, $row, $!l-pad ~ $line ~ $!r-pad;
        last if ++$row > $.geom.bottom;
    }
}
