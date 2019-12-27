use v6;
use Test;
use Vikna::App;
use Vikna::Canvas;
use Vikna::Utils;

plan 6;

class MyApp is Vikna::App {
}

my $app = MyApp.new;

role not-passed { }
sub test-filled-rect(Vikna::Canvas:D $c, $x, $y, $w, $h, $char, Str:D $msg,
                    BasicColor :$fg = Any but not-passed, BasicColor :$bg = Any but not-passed)
{
    subtest "Filled canvas rectangle: " ~ $msg => {
        plan 4;
        ok $c.geom.contains-rect($x, $y, $w, $h), "required rectangle fits into the canvas";
        my $char-matches = 0;
        my $fg-matches = 0;
        my $bg-matches = 0;
        for $y..($y + $h - 1) -> $row {
            for $x..($x + $w - 1) -> $col {
                given $c.pick($col, $row) {
                    ++$char-matches if .char ~~ $char;
                    ++$fg-matches if $fg ~~ not-passed || .fg ~~ $fg;
                    ++$bg-matches if $bg ~~ not-passed || .bg ~~ $bg;
                }
            }
        }
        my $expected-matches = $w * $h;
        is $char-matches, $expected-matches, "all characters match";
        if $fg ~~ not-passed {
            pass "fg color parameter not passed";
        }
        else {
            is $fg-matches, $expected-matches, "all fg colors match";
        }
        if $bg ~~ not-passed {
            pass "bg color parameter not passed";
        }
        else {
            is $bg-matches, $expected-matches, "all bg colors match";
        }
    }
}

subtest "Paintable rectangles" => {
    plan 14;
    my $c = Vikna::Canvas.new: :w<120>, :h<40>;

    is $c.invalidates.elems, 0, "no invalidated rects by default";
    nok $c.is-paintable( 10, 10 ), "by default the whole canvas is unpaintable";
    $c.invalidate;
    is $c.invalidates.elems, 1, "invalidating canvas adds one invalidation";
    ok $c.is-paintable( 10, 10 ), "invalidating makes whole canvas paintable";
    nok $c.is-paintable(130, 1), "too big X";
    nok $c.is-paintable(1, 50), "too big Y";

    $c.clear-inv-rect;
    $c.add-inv-rect: 10, 15, 20, 5;
    $c.add-inv-rect: 50, 10, 10, 20;

    ok $c.is-paintable(11, 17), "inside first rect";
    ok $c.is-paintable(55, 16), "inside second rect";
    ok $c.is-paintable(10, 15), "inside, upper left corner";
    ok $c.is-paintable(29, 19), "inside, bottom right corner";
    nok $c.is-paintable(5, 16), "outside, left to the rect 1";
    nok $c.is-paintable(12, 1), "outside, above the rect 1";
    nok $c.is-paintable(32, 17), "outside, right to the rect 1";
    nok $c.is-paintable(12, 25), "outside, under the rect 1";
}

subtest "Overlapping invalidation" => {
    plan 1;
    my $c = Vikna::Canvas.new: :w<120>, :h<40>;

    $c.invalidate(1, 4, 50, 17);
    $c.invalidate(40, 7, 21, 12);
    $c.invalidate(33, 15, 38, 26);
    $c.invalidate(35, 10, 21, 10);
    is $c.invalidates.elems, 3, "one invalidation is not added because covered by existing ones";
}

subtest "Invalidated painting" => {
    plan 38;
    my $c = Vikna::Canvas.new: :w<25>, :h<10>;

    sub test-points(**@p) {
        for @p -> (:key($char), :value(@points)) {
            for @points -> @c {
                is $c.pick(@c[0], @c[1]).char, $char, "found '$char' at {@c[0]},{@c[1]}";
            }
        }
    }

    $c.invalidate;
    for ^$c.h {
        $c.imprint(0, $_, '.' x $c.w);
    }
    $c.clear-inv-rect;

    test-points
        '.' => (
            [5,  2],
            [14, 2],
            [14, 4],
            [5,  4],
        ),
        ;

    $c.invalidate(5, 2, 10, 3);
    for ^$c.h {
        $c.imprint(0, $_, 'x' x $c.w);
    }
    test-points
        'x' => (
            [5,  2],
            [14, 2],
            [14, 4],
            [5,  4],
        ),
        '.' => (
            [4,  2], [5,  1],
            [15, 2], [14, 1],
            [15, 4], [14, 5],
            [4,  4], [5,  5],
        )
        ;

    $c.invalidate(7, 4, 10, 3);
    for ^$c.h {
        $c.imprint(0, $_, 'o' x $c.w);
    }

    test-points
        'o' => (
            [5, 2], [14, 2], [14, 4], [5, 4],
            [7, 4], [16, 4], [16, 6], [7, 6],
        ),
        '.' => (
            [4, 2], [5, 1], [15, 2], [14, 1], [4, 4], [5, 5], [15, 3],
            [16, 3], [17, 4], [17, 6], [16, 7], [7, 7], [6, 6], [6, 5]
        )
        ;
}

subtest "Coloring" => {
    plan 4;
    my $c = Vikna::Canvas.new: :w<25>, :h<10>;
    $c.invalidate;
    for ^10 {
        $c.imprint(0, $_, '.' x 25);
    }
    $c.viewport: 1, 1, 13, 4;

    my $sample = "Some text";
    $c.imprint(1, 1, $sample, :text-only);
    is-deeply
        (1..^(1 + $sample.chars)).map( { $c.pick($_, 1).char } ),
        $sample.comb,
        "all chars in place";
    $c.imprint(2, 1, 4, 3, :bg(50,80,0));

    sub test-colored-rect($canvas, $x, $y, $w, $h, $ul-char, $br-char, $msg, *%c) {
        $c.imprint($x, $y, $w, $h, |%c);
        my @tpoints = {msg => "Upper left", :$x, :$y, char => $ul-char},
                      {msg => "Bottom right", :x($x + $w - 1), :y($y + $h - 1), char => $br-char};
        subtest $msg => {
            for @tpoints -> %t {
                subtest %t<msg> ~ " corner at {%t<x>},{%t<y>}"  => {
                    my $cell = $c.pick(%t<x>, %t<y>);
                    is $cell.^name, 'Vikna::Canvas::Cell', 'cell type';
                    is $cell.char, %t<char>, 'char is preserved';
                    with %c<fg> {
                        is $cell.fg, %c<fg>, 'fg color';
                    }
                    else {
                        nok ?$cell.fg, 'fg color not specified';
                    }
                    with %c<bg> {
                        is $cell.bg, %c<bg>, 'bg color';
                    }
                    else {
                        nok ?$cell.bg, 'bg color not specified';
                    }
                }
            }
        }
    }

    test-colored-rect($c, 2, 1, 5, 3, 'o', '.', "Only background color", :bg('50,80,0'));
    test-colored-rect($c, 3, 1, 2, 2, 'm', '.', "Foreground and background", :fg<red>, :bg('50,80,0'));

    is $app.screen.print(30, 3, $c.viewport, :str).comb.map({ .ord == 27 ?? '<ESC>' !! $_ }).join,
        q{<ESC>[4;31H<ESC>[0mS<ESC>[0m<ESC>[48;2;50;80;0mo<ESC>[0m<ESC>[31;48;2;50;80;0mme<ESC>[0m<ESC>[48;2;50;80;0m t<ESC>[0mext....<ESC>[0m<ESC>[5;31H<ESC>[0m.<ESC>[0m<ESC>[48;2;50;80;0m.<ESC>[0m<ESC>[31;48;2;50;80;0m..<ESC>[0m<ESC>[48;2;50;80;0m..<ESC>[0m.......<ESC>[0m<ESC>[6;31H<ESC>[0m.<ESC>[0m<ESC>[48;2;50;80;0m.....<ESC>[0m.......<ESC>[0m<ESC>[7;31H<ESC>[0m.............<ESC>[0m},
        "resulting output string";
}

subtest "Transparency" => {
    plan 1;
    my $c = Vikna::Canvas.new: :w<25>, :h<10>;
    $c.invalidate: 0, 0, 5, 1;
    $c.invalidate: 10, 0, 5, 1;
    for ^10 {
        $c.imprint(0, $_, 'X' x 25);
    }
    is $app.screen.print(30, 3, $c.viewport, :str).comb.map({ .ord == 27 ?? '<ESC>' !! $_ }).join,
        q{<ESC>[4;31H<ESC>[0mXXXXX<ESC>[4;41HXXXXX<ESC>[0m<ESC>[5;31H<ESC>[0m<ESC>[0m<ESC>[6;31H<ESC>[0m<ESC>[0m<ESC>[7;31H<ESC>[0m<ESC>[0m<ESC>[8;31H<ESC>[0m<ESC>[0m<ESC>[9;31H<ESC>[0m<ESC>[0m<ESC>[10;31H<ESC>[0m<ESC>[0m<ESC>[11;31H<ESC>[0m<ESC>[0m<ESC>[12;31H<ESC>[0m<ESC>[0m<ESC>[13;31H<ESC>[0m<ESC>[0m},
        "Transprent cells are not output";
}

subtest "Canvas -> canvas imprinting" => {
    plan 17;
    my $cbase = Vikna::Canvas.new: :w<25>, :h<10>;
    $cbase.invalidate;
    $cbase.fill("*");

    test-filled-rect $cbase, 0, 0, 25, 10, '*', 'canvas fully filled';

    my $ctop = Vikna::Canvas.new: :w<5>, :h<3>;
    $ctop.invalidate;
    $ctop.fill(" ");

    $cbase.imprint(1,1, $ctop);

    test-filled-rect $cbase, 1, 1, 5, 3, " ", "imprinted plain spaces";
    # $app.screen.print(30,10, $cbase);
    # sleep 1;

    $cbase.clear-inv-rect;

    $ctop = $cbase.new-from-self;
    $ctop.invalidate;
    $ctop.fill("×", :fg<yellow>);

    test-filled-rect $ctop, 0, 0, $cbase.w, $cbase.h, "×", "prepared top canvase", :fg<yellow>;

    $cbase.invalidate(5,3,5,2);
    $cbase.invalidate(7, 7, 4, 1);
    $cbase.imprint(0,0,$ctop);
    # $app.screen.print(30,10, $cbase);
    # sleep 1;

    test-filled-rect $cbase, 5, 3, 5, 2, "×", "imprinted by invalidation #1", :fg<yellow>;
    test-filled-rect $cbase, 7, 7, 4, 1, "×", "imprinted by invalidation #2", :fg<yellow>;
    test-filled-rect $cbase, 1, 1, 3, 3, " ", "area outside of invalidation is untouched #1";
    test-filled-rect $cbase, 1, 1, 4, 2, " ", "area outside of invalidation is untouched #2";
    test-filled-rect $cbase, 0, 5, $cbase.w, 2, "*", "area outside of invalidation is untouched #3";
    test-filled-rect $cbase, 10, 0, 14, 7, "*", "area outside of invalidation is untouched #4";

    $cbase.clear-inv-rect;
    $cbase.invalidate;
    $ctop = $cbase.new-from-self;
    $ctop.invalidate(0,1,24,9);
    $ctop.fill("⚛", :fg<green>);
    $ctop.clear-inv-rect;
    $ctop.invalidate(0,0,25,1);
    $ctop.imprint(0,0,25,1, :bg<blue>);
    $cbase.imprint(8,4,$ctop);
    # $app.screen.print(30,10, $cbase);
    # sleep 3;

    test-filled-rect $cbase, 8, 5, 17, 5, "⚛", "imprint with transparent cells: non-transparent", :fg<green>;
    test-filled-rect $cbase, 10, 4, 15, 1, "*", "imprint with transparent cells: transparent, bg from imprint", :bg<blue>;
    test-filled-rect $cbase, 8, 4, 2, 1, "×", "imprint with transparent cells: transparent, fg from base, bg from imprint", :fg<yellow>, :bg<blue>;
    test-filled-rect $cbase, 5, 4, 3, 1, "×", "imprint with transparent cells: outside unchanged", :fg<yellow>;

    my $cdup = $cbase.dup;

    test-filled-rect $cdup, 8, 5, 17, 5, "⚛", "dup: imprint with transparent cells: non-transparent", :fg<green>;
    test-filled-rect $cdup, 10, 4, 15, 1, "*", "dup: imprint with transparent cells: transparent, bg from imprint", :bg<blue>;
    test-filled-rect $cdup, 8, 4, 2, 1, "×", "dup: imprint with transparent cells: transparent, fg from base, bg from imprint", :fg<yellow>, :bg<blue>;
    test-filled-rect $cdup, 5, 4, 3, 1, "×", "dup: imprint with transparent cells: outside unchanged", :fg<yellow>;
}

done-testing;

# vim: ft=perl6
