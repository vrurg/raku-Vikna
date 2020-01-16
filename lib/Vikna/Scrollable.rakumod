use v6.e.PREVIEW;
unit role Vikna::Scrollable;

use Vikna::Events;

has Int:D $.lines = 0;          # How "tall" is the object
has Int:D $.columns = 0;        # How "wide" is the object
has Int:D $.dx = 0;             # Current horizontal position, left-to-right
has Int:D $.dy = 0;             # Current vertical position, top-to-bottom
has Bool:D $.w-fit = False;     # Don't scroll beyond right
has Bool:D $.h-fit = False;     # Don't scroll beyond bottom
has $!old-x = 0;
has $!old-y = 0;

method w {...}
method h {...}

# This method is thread-unsafe. It's up to the calling methods to take care.
method !adjust-pos {
    return if $*VIKNA-SCROLLABLE-NO-ADJUST;
    $.trace: "ADJUST-POS";
    $!dx = $!columns - $.w if $!w-fit && (($!dx + $.w) > $!columns);
    $!dy = $!lines - $.h if $!h-fit && (($!dy + $.h) > $!lines);
    $!dx max= 0;
    $!dy max= 0;
    $.trace: "old-x: ", $!old-x, " -> ", $!dx;
    $.trace: "old-y: ", $!old-y, " -> ", $!dy;
    self.?dispatch:
            Event::Scroll::Position,
            from => Vikna::Point.new($!old-x, $!old-y),
            to => Vikna::Point.new($!dx, $!dy)
        if $!dx != $!old-x || $!dy != $!old-y;
    $!old-x = $!dx;
    $!old-y = $!dy;
}

method !scroll(Int:D :$dx = 0, Int:D :$dy = 0 --> Nil) {
    $!dx += $_ with $dx;
    $!dy += $_ with $dy;
    self!adjust-pos;
}

method !scroll-to(Int $x, Int $y) {
    $!dx = $_ with $x;
    $!dy = $_ with $y;
    self!adjust-pos;
}

method !set-area(Int:D :$w where * >= 0, Int:D :$h where * >= 0) {
    $.trace: "*** set area";
    $!columns = $_ with $w;
    $!lines   = $_ with $h;
    self!adjust-pos;
}

method !fit(Bool:D :$width?, Bool:D :$height?) {
    $.w-fit = $_ with $width;
    $.h-fit = $_ with $height;
    self!adjust-pos
}

### Utility methods ###

#| Do a couple of operations as a single transaction, run adjust-pos afterwards.
method scroll-transaction(&code) {
    {
        my $*VIKNA-SCROLLABLE-NO-ADJUST = True;
        &code()
    }
    self!adjust-pos;
}
