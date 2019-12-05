use v6;
unit role Term::UI::Scrollable;
use Term::UI::Events;

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

method !adjust-pos {
    $!dx = $!columns - $.w if $!w-fit && (($!dx + $.w) > $!columns);
    $!dy = $!lines - $.h if $!h-fit && (($!dy + $.h) > $!lines);
    $!dx max= 0;
    $!dy max= 0;
    self.?dispatch(Event::ScrollPosition, :$!old-x, :$!old-y, :x($!dx), :y($!dy))
        if $!dx != $!old-x || $!dy != $!old-y;
    $!old-x = $!dx;
    $!old-y = $!dy;
}

method scroll(Int:D :$dx = 0, Int:D :$dy = 0 --> Nil) {
    $!dx += $dx;
    $!dy += $dy;
    self!adjust-pos unless 0 ~~ $dx & $dy;
}

method set-pos(Int :$dx?, Int :$dy? --> Nil) {
    $!dx = $_ with $dx;
    $!dy = $_ with $dy;
    self!adjust-pos;
}

method set-area(Int:D :$!lines where * >= 0, Int:D :$!columns where * >= 0) { self!adjust-pos }

#| Set fit flags.
method fit(Bool:D :$width?, Bool:D :$height?) {
    $.w-fit = $_ with $width;
    $.h-fit = $_ with $height;
    self!adjust-pos
}

multi method event(Event::Resize:D $ev) {
    self!adjust-pos if $ev.old-w != $.w || $ev.old-h != $.h;
}
