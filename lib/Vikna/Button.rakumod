use v6.e.PREVIEW;

unit class Vikna::Button;

use Vikna::Events;
use Vikna::Focusable;
use Vikna::PointerTarget;
use Vikna::Widget;
use Vikna::Utils;
use AttrX::Mooish;

also is Vikna::Focusable;
also does Vikna::PointerTarget;

has Bool $.is-unicode is mooish(:lazy);
has Bool $.use3d is mooish(:lazy);
has Str:D $.text is required;
has $.shadow-color;

# If defined, $.event would be sent to this target widget.
has Vikna::Widget $.target is rw;
# Could be an instance too.
has Event::Button $.event = Event::Button::Press;

has Bool:D $!pressed = False;

### Utility methods ###

submethod profile-default {
    :h(1), :text<Ok>, :!auto-clear,
    attr => { :fg<default>, :bg('magenta'), :pattern(' ') },
    focused-attr => { :fg<black>, :bg<green>, :pattern(' ') },
    :shadow-color<black>
}

submethod profile-checkin(%profile, %constructor, %, %) {
    # .trace: "Button profile for checkin: ", %profile with %profile<app>;
    my %geom-profile;
    my $use3d = %profile<use3d>;
    %geom-profile<w> = %profile<text>.chars + ($use3d ?? 3 !! 4) unless %constructor<w>;
    unless %constructor<h> {
        %geom-profile<h> = $use3d ?? 2 !! 1
    }
    if %geom-profile {
        %profile<geom> = %profile<geom>.dup: |%geom-profile;
    }
    # .trace: "Updated profile for ", self.^name, "::new\n", %profile.map({ .key ~ " => " ~ (.value ~~ Vikna::Object ?? .value.WHICH !! .value.raku) }).join("\n")
    #     with %profile<app>;
}

method build-is-unicode {
    $.app.screen.is-unicode
}

method build-use3d {
    $.h > 1
}

### Event handlers ###

multi method event(Event::Mouse::Press:D $ev) {
    nextsame unless $ev.button == MBLeft;
    unless $.in-focus {
        $.focus;
    }
    self!set-pressed(True);
}

multi method event(Event::Mouse::Release:D $ev) {
    nextsame unless $ev.button == MBLeft;
    self!set-pressed(False, :report)
}

# multi method event(Event::Mouse::Enter:D $ev) {
#     nextsame unless $ev.buttons[MBLeft];
#     self!set-pressed(True);
# }

multi method event(Event::Mouse::Leave:D $ev) {
    nextsame unless $ev.buttons[MBLeft];
    self!set-pressed(False);
}

multi method event(Event::Kbd:D $ev) {
    if $ev.char eq ' ' {
        self!set-pressed(True);
        self!set-pressed(False, :report);
    }
}

### Utility methods ###

method !set-pressed($pressed, :$report?) {
    if $!pressed xor $pressed {
        self.trace: "pressed state change from $!pressed into $pressed";
        $!pressed = ? $pressed;
        self.dispatch: $!pressed ?? Event::Button::Down !! Event::Button::Up;
        if $report && $!target && ! $!pressed {
            self.dispatch: Event::Button::Press;
            if $!event.defined {
                $!target.dispatch: $!event.dup(:origin(self));
            }
            else {
                $!target.dispatch: $!event, :origin(self)
            }
        }
        $.cmd-redraw(:force);
    }
}

# method !still-pressed {
#     # XXX If any other pointers get support they must be handled here too.
#     $!pressed &&= $.parent.is-pointer-owner('mouse', self);
# }

method draw3d(:$canvas) {
    self.trace: "3D button\n - size: ", $.geom, "\n - viewport: ", $.viewport, "\n - pressed: ", $!pressed;
    my $bw = $.w - 1;
    # $canvas.invalidate: $.invalidate;
    $canvas.clear;
    $canvas.invalidate: self.invalidate: 0, 0, $bw, 1;
    $canvas.invalidate: self.invalidate: 1, 1, $bw, 1;
    my $outtext = $!text.substr(0, $bw);
    my $y = $!pressed ?? 1 !! 0;
    my $x = $y + (($bw - $outtext.chars) / 2).truncate;
    unless $!pressed {
        self.trace: "Unpressed button";
        $canvas.imprint: 1, 1, ' ' x $bw, bg => $!shadow-color, fg => $!shadow-color;
    }
    self.trace: "Imprinting ‘$outtext’ into $x, $y";
    $canvas.imprint: $y, $y, $.attr.pattern x $bw, bg => $.attr.bg, fg => $.attr.fg;
    $canvas.imprint: $x, $y, $outtext, bg => $.attr.bg, fg => $.attr.fg;
}

method draw2d(:$canvas) {
    $.invalidate;
    self.draw-background(:$canvas);
    my @braces = $!pressed ?? «( )» !! «< >»;
    my $btext = @braces[0] ~ " " ~ $!text ~ " " ~ @braces[1];
    my $y = (($.h - 1) / 2).truncate;
    my $x = (($.w - $btext.chars) / 2).truncate;
    $canvas.imprint: $x, $y, $btext, :$.fg, bg => $.bg ~ ($!pressed ?? " bold" !! "");
}

method draw(:$canvas) {
    # self!still-pressed;
    if $!use3d {
        self.draw3d: :$canvas
    }
    else {
        self.draw2d: :$canvas
    }
}
