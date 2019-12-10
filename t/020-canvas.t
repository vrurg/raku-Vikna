use v6;
use Test;
use Vikna::Canvas;

plan 4;

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

    $c.invalidate-reset;
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
    is-deeply $c.cells[1;1..^(1 + $sample.chars)], $sample.comb, "all chars in place";
    $c.imprint(2, 1, 4, 3, :bg('50,80,0'));

    sub test-colored-rect($canvas, $x, $y, $w, $h, $ul-char, $br-char, $msg, *%c) {
        $c.imprint($x, $y, $w, $h, |%c);
        my @tpoints = {msg => "Upper left", :$x, :$y, char => $ul-char},
                      {msg => "Bottom right", :x($x + $w - 1), :y($y + $h - 1), char => $br-char};
        subtest $msg => {
            for @tpoints -> %t {
                subtest %t<msg> ~ " corner" => {
                    my $cell = $c.cells[%t<y>; %t<x>];
                    is $cell.^name, 'Vikna::Canvas::Cell', 'cell type';
                    is $cell.char, %t<char>, 'char is preserved';
                    is $cell.bg, %c<bg> // Str, 'bg color';
                    is $cell.fg, %c<fg> // Str, 'fg color';
                }
            }
        }
    }

    test-colored-rect($c, 2, 1, 5, 3, 'o', '.', "Only background color", :bg('50,80,0'));
    test-colored-rect($c, 3, 1, 2, 2, 'm', '.', "Foreground and background", :fg<red>, :bg('50,80,0'));

    is $c.viewport(30,3).comb.map({ .ord == 27 ?? '<ESC>' !! $_ }).join,
        q{<ESC>[4;31HS<ESC>[0m<ESC>[48;2;50;80;0mo<ESC>[0m<ESC>[31;48;2;50;80;0mme<ESC>[0m<ESC>[48;2;50;80;0m t<ESC>[0mext....<ESC>[5;31H.<ESC>[0m<ESC>[48;2;50;80;0m.<ESC>[0m<ESC>[31;48;2;50;80;0m..<ESC>[0m<ESC>[48;2;50;80;0m..<ESC>[0m.......<ESC>[6;31H.<ESC>[0m<ESC>[48;2;50;80;0m.....<ESC>[0m.......<ESC>[7;31H.............},
        "resulting output string";
}

subtest "Invalidated painting" => {
    plan 38;
    my $c = Vikna::Canvas.new: :w<25>, :h<10>;

    sub test-points(**@p) {
        for @p -> (:key($char), :value(@points)) {
            for @points -> @c {
                is $c.cells[@c[1];@c[0]], $char, "found '$char' at {@c[0]},{@c[1]}";
            }
        }
    }

    $c.invalidate;
    for ^$c.h {
        $c.imprint(0, $_, '.' x $c.w);
    }
    $c.invalidate-reset;

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

done-testing;

# vim: ft=perl6
