use v6.e.PREVIEW;

unit class Button;

use Vikna::Events;
use Vikna::Focusable;
use Vikna::PointerTarget;
use Vikna::Widget;

also does Vikna::Focusable;
also does Vikna::PointerTarget;
also is Vikna::Widget;

has Str:D $.text is required;

### Utility methods ###

method profile-default {
    %(
        h => 1,
        text => "Ok",
    )
}

submethod profile-checkin(%profile, %, %, %) {
    %profile<w> = %profile<text>.chars + 4 unless %profile<w>;
    %profile<h> = 1 if %profile<h> < 1;
}

method draw(:$canvas) {
    $.invalidate;
    self.draw-background(:$canvas);
    my $btext = "< " ~ $!text ~ " >";
    my $y = (($.h - 1) / 2).truncate;
    my $x = (($.w - $btext.chars) / 2).truncate;
    $canvas.imprint: $x, $y, $btext, :$.fg, :$.bg;
}
