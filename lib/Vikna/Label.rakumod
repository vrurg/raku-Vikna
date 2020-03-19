use v6.e.PREVIEW;
use Vikna::Widget;
unit class Vikna::Label;
also is Vikna::Widget;

use Vikna::Events;
use AttrX::Mooish;

has Str:D $.text is required;
has Str $.l-pad is mooish(:lazy<default-pad>);
has Str $.r-pad is mooish(:lazy<default-pad>);

submethod profile-default {
    pattern => " ",
    h       => 1,
    :auto-clear
}

method default-pad { $.attr.pattern // ' ' }

### Command handlers ###
method cmd-settext(Str:D $text) {
    my $old-text = $!text;
    $!text = $text;
    self.dispatch: Event::Changed::Text, :$old-text, :$text;
    self.invalidate;
    self.redraw;
}

### Command senders ###
method set-text(::?CLASS:D: Str:D $text) {
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
