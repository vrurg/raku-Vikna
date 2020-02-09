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

submethod TWEAK {
    self.throw: X::Terminal::NoTERM unless %*ENV<TERM>:exists;
    signal(SIGWINCH).tap: { self.screen-resize }
}

method build-is-unicode {
    %*ENV<TERM>.fc.contains: "utf".fc
}

method build-geom {
    Vikna::Rect.new: 0, 0, w => columns(), h => rows()
}

method build-cursor-sub {
    move-cursor-template($!terminal-profile)
}

my %color-cache = '' => '';
my $cc-lock = Lock.new;
multi method ansi-color(Vikna::Canvas::Cell:D $cell) {
    self.ansi-color: :fg($cell.fg), :bg($cell.bg);
}
multi method ansi-color(Vikna::Color :$fg?, Vikna::Color :$bg?) {
    self.ansi-color: :fg($fg.Str), :bg($bg.Str)
}
multi method ansi-color(:$fg?, :$bg?) {
    my $cl := nqp::list();
    nqp::stmts(
        nqp::if($fg, nqp::push($cl, nqp::decont($fg))),
        nqp::if($bg, nqp::push($cl, "on_{$bg}")),
    );
    nqp::join(" ", $cl)
}

method color2esc(BasicColor $color) {
    $color ?? color($color) !! ''
}

proto method screen-print(::?CLASS:D: Int:D, Int:D, |) {*}

multi method screen-print(Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, *%c ) {
    $*OUT.print: $.ANSI-str( $x, $y, $viewport, :str, |%c )
}

multi method screen-print(Int:D $x, Int:D $y, Str:D $string, Vikna::Color:D :$fg?, Vikna::Color:D :$bg?) {
    $*OUT.print: &!cursor-sub($x, $y) ~ $.color2esc(self.ansi-color: :$fg, :$bg) ~ $string ~ RESET-COLOR
}

multi method ANSI-str( ::?CLASS:D: Int:D $x, Int:D $y, Vikna::Canvas:D $viewport, :$default-fg?, :$default-bg?)
{
    my $vlines := nqp::list();
    my $default-color := $.color2esc( $.ansi-color(fg => $default-fg, bg => $default-bg) );
    my ($cplane, $fgplane, $bgplane);
    $viewport.get-planes($cplane, $fgplane, $bgplane);
    my $vw = $viewport.w;
    my $vh = $viewport.h;
    my $vrow = -1;
    nqp::while(
        ++$vrow < $vh,
        nqp::stmts(
            nqp::push($vlines, nqp::decont(&!cursor-sub($x, $y + $vrow))),
            nqp::push($vlines, RESET-COLOR),
            (my $last-color = ''),
            (my $need-col-change := 0),
            (my $crow := nqp::atpos(nqp::decont($cplane), $vrow)),
            (my $fgrow := nqp::atpos(nqp::decont($fgplane), $vrow)),
            (my $bgrow := nqp::atpos(nqp::decont($bgplane), $vrow)),
            (my $vcol = -1),
            nqp::while(
                ++$vcol < $vw,
                nqp::stmts(
                    (my $char := nqp::defor(nqp::atpos($crow, $vcol), '')),
                    (my $fg = nqp::atpos($fgrow, $vcol)),
                    (my $bg = nqp::atpos($bgrow, $vcol)),
                    (my $color := nqp::decont($.ansi-color(:$fg, :$bg))),
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

multi method color(Str:D $name) {
    # Strings of form "R,G,B,A" are to be converted into positionals
    return self.color( |$name.split(",").map: *.Int ) if $name.index(",");
    note "named color($name)";
    my @ns = <X11 XKCB CSS>;
    my @rgb;
    for @ns -> $n {
        with Color::Names.color-data($n){$name} {
            @rgb.append: |$_<rgb>;
            note "= FOUND: [{@rgb}]";
            last
        }
    }
    # TODO add support for terminal numeric colors
    note "= CREATING COLOR OBJ";
    Vikna::Color::Named.new: :$name, |%(<r g b> Z=> @rgb)
}

multi method color(UInt:D $r, UInt:D $g, UInt:D $b, UInt:D $a = 255) {
    Vikna::Color::RGB.new: :$r, :$g, :$b, :$a
}

# multi method color(@chan) {
#     Vikna::Color::RGB.new: |%( <r g b a> Z=> @chan )
# }

multi method color(*%chan) {
    Vikna::Color::RGB.new: |%chan
}

multi method color(Vikna::Color:D $c) {
    $c.clone
}

method init { }

method shutdown { }
