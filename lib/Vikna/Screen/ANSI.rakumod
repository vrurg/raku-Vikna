use v6.e.PREVIEW;
use nqp;
use Vikna::Screen;
use Vikna::Color;

unit class Vikna::Screen::ANSI;
also does Vikna::Screen;

use Color::Names;
use Color;
use AttrX::Mooish;
use Terminal::Print::Commands;
use Terminal::ANSIColor;
use Vikna::Canvas;
use Vikna::Color::RGB;
use Vikna::Color::Named;
use Vikna::Utils;

constant RESET-COLOR = color('reset');

has Str $.terminal-profile = 'ansi'; # or universal
has &.cursor-sub is mooish(:lazy);
has $!cursor-hidden;
has UInt:D $!cursor-x = 0;
has UInt:D $!cursor-y = 0;

submethod TWEAK {
    self.throw: X::Terminal::NoTERM unless %*ENV<TERM>:exists;
    signal(SIGWINCH).tap: { self.flow: :sync, :name('SCREEN RESIZE'), { self.screen-resize } }
}

method build-is-unicode {
    %*ENV<TERM>.fc.contains: "utf".fc
}

method build-color-depth {
    24 # just stub it for now
}

method build-geom {
    Vikna::Rect.new: 0, 0, w => columns(), h => rows()
}

method build-cursor-sub {
    move-cursor-template($!terminal-profile)
}

multi method ansi-color(Vikna::Canvas::Cell:D $cell) {
    self.ansi-color: :fg($cell.fg), :bg($cell.bg), :style($cell.style);
}
multi method ansi-color(Vikna::Color :$fg?, Vikna::Color :$bg?, :$style?) {
    self.ansi-color: :fg($fg.Str), :bg($bg.Str), :$style
}
# Qhick map of style Int representation into a string.
my $style-shortcuts := nqp::list(
    '', 'bold', 'italic', 'bold italic', 'underline', 'bold underline', 'italic underline', 'bold italic underline'
);
multi method ansi-color(:$fg?, :$bg?, :$style?) {
    my $cl := nqp::list();
    nqp::stmts(
        nqp::if($fg, nqp::push($cl, nqp::decont($fg))),
        nqp::if($bg, nqp::push($cl, "on_{$bg}")),
        nqp::if(
            nqp::if(nqp::defined($style), nqp::bitand_i($style, VSBase)),
            nqp::push($cl, nqp::atpos($style-shortcuts, nqp::bitand_i($style, VSMask))))
    );
    nqp::join(" ", $cl)
}

method color2esc(BasicColor $color) {
    $color ?? color($color) !! ''
}

method !OUT-PRINT(Str:D $line) {
    print-command 'hide-cursor', $!terminal-profile;
    $*OUT.print: $line;
    $*OUT.print: &!cursor-sub($!cursor-x, $!cursor-y);
    print-command 'show-cursor', $!terminal-profile unless $!cursor-hidden;
}

proto method screen-print(::?CLASS:D: Int:D, Int:D, |) {*}

multi method screen-print(Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, *%c ) {
    self!OUT-PRINT: $.ANSI-str( $x, $y, $viewport, |%c )
}

multi method screen-print(Int:D $x, Int:D $y, Str:D $string, Vikna::Color:D :$fg?, Vikna::Color:D :$bg?, :$style?) {
    self!OUT-PRINT: &!cursor-sub($x, $y) ~ $.color2esc(self.ansi-color: :$fg, :$bg, :style(to-style($style))) ~ $string ~ RESET-COLOR
}

multi method screen-print(Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, :$str! where *.so, *%c) {
    $.ANSI-str($x, $y, $viewport, |%c)
}

method ANSI-str( ::?CLASS:D: Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, :$default-fg?, :$default-bg?, :$default-style?)
{
    my $vlines := nqp::list();
    my $default-color := $.color2esc( $.ansi-color(fg => $default-fg, bg => $default-bg, style => to-style($default-style)) );
    my ($cplane, $fgplane, $bgplane, $stplane);
    $viewport.get-planes($cplane, $fgplane, $bgplane, $stplane);

    # Limit the rectangle we update to the outer boundaries of viewport invalidations
    my ($xshift, $yshift, $xmax, $ymax) = (.right, .bottom, 0, 0) with $.geom;
    for $viewport.invalidations {
        $xshift min= .x;
        $yshift min= .y;
        $xmax   max= .right;
        $ymax   max= .bottom;
    }

    my $vrow = $yshift - 1;
    my ($char, $fg, $bg, $style, $color, $skip);
    nqp::while(
        ++$vrow <= $ymax,
        nqp::stmts(
            nqp::push($vlines, nqp::decont(&!cursor-sub($x + $xshift, $y + $vrow))),
            nqp::push($vlines, RESET-COLOR),
            (my $last-color = ''),
            (my $need-col-change := 0),
            (my $crow := nqp::atpos(nqp::decont($cplane), $vrow)),
            (my $fgrow := nqp::atpos(nqp::decont($fgplane), $vrow)),
            (my $bgrow := nqp::atpos(nqp::decont($bgplane), $vrow)),
            (my $strow := nqp::atpos(nqp::decont($stplane), $vrow)),
            (my $vcol = $xshift - 1),
            ($fg := ''),
            ($bg := ''),
            ($style := VSTransparent),
            ($skip := 1),
            nqp::while(
                ++$vcol <= $xmax,
                nqp::stmts(
                    nqp::if(
                        $viewport.is-paintable($vcol, $vrow),
                        nqp::stmts(
                            ($char := nqp::defor(nqp::atpos($crow, $vcol), '')),
                            ($fg := nqp::atpos($fgrow, $vcol)),
                            ($bg := nqp::atpos($bgrow, $vcol)),
#                            ($bg := nqp::if($viewport.is-paintable($vcol, $vrow), '0,100,60', nqp::atpos($bgrow, $vcol))),
                            ($style := nqp::atpos($strow, $vcol)),
                            ($color := nqp::decont($.ansi-color(:$fg, :$bg, :style($style.ord)))),
                            ($skip := 0)
                        ),
                        nqp::stmts(
                            ($char := ''),
                            ($color := ''),
                            ($skip := 1)
                        ),
                    ),
                    nqp::if(
                        nqp::isne_s($color, $last-color),
                        nqp::stmts(
                            nqp::push($vlines, RESET-COLOR),
                            nqp::if(
                                $color,
                                nqp::push($vlines, $.color2esc($color)),
                                nqp::push($vlines, $default-color)
                            )
                        )
                    ),
                    nqp::if(
                        $char,
                        nqp::stmts(
                            nqp::if(
                                $need-col-change,
                                nqp::stmts(
                                    nqp::push($vlines, nqp::decont(&!cursor-sub($x + $vcol, $y + $vrow))),
                                    ($need-col-change := 0)
                                )
                            ),
                            nqp::push($vlines, nqp::decont($char)),
                        ),
                        ($need-col-change := 1)
                    ),
                    ($last-color = $color)
                )
            ),
            nqp::push($vlines, RESET-COLOR)
        )
    );
    # my @v = $vlines;
    # note @v.perl;
    nqp::join("", $vlines);
}

# multi method color(Str:D $name) {
#     # Strings of form "R,G,B,A" are to be converted into positionals
#     return self.color( |$name.split(",").map: *.Int ) if $name.index(",");
#     my @ns = <X11 XKCB CSS>;
#     my @rgb;
#     for @ns -> $n {
#         with Color::Names.color-data($n){$name} {
#             @rgb.append: |$_<rgb>;
#             last
#         }
#     }
#     # TODO add support for terminal numeric colors
#     Vikna::Color::Named.new: :$name, |%(<r g b> Z=> @rgb)
# }
#
# multi method color(UInt:D $r, UInt:D $g, UInt:D $b, UInt:D $a?) {
#     Vikna::Color::RGB.new: :$r, :$g, :$b, :$a
# }
#
# multi method color(*%chan) {
#     Vikna::Color::RGB.new: |%chan
# }
#
# multi method color(Vikna::Color:D $c) {
#     $c.clone
# }

method hide-cursor {
    print-command 'hide-cursor', $!terminal-profile;
    $!cursor-hidden = True;
}

method show-cursor {
    print-command 'show-cursor', $!terminal-profile;
    $!cursor-hidden = False;
}

multi method move-cursor(UInt:D $x, UInt:D $y) {
    ($!cursor-x, $!cursor-y) = ($x, $y);
    $*OUT.print: &!cursor-sub($!cursor-x, $!cursor-y);
}

method init {
    # print-command 'save-screen', $!terminal-profile;
    # print-command 'clear', $!terminal-profile;
}

method shutdown {
    # print-command 'clear', $!terminal-profile;
    # print-command 'restore-screen', $!terminal-profile;
    self.Vikna::Screen::shutdown;
}
