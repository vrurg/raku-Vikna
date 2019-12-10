use v6;
use Test;
use Vikna::Rect;
use Vikna::Point;

plan 3;

subtest "Rect objects" => {
    plan 9;
    my $r = Vikna::Rect.new(1, 5, 42, 13);
    isa-ok $r, Vikna::Rect, "new rectangle object from positionals";
    is $r.x, 1, "x pos";
    is $r.y, 5, "y pos";
    is $r.w, 42, "width";
    is $r.h, 13, "height";
    is $r.right, 42, "right border";
    is $r.bottom, 17, "bottom border";
    is-deeply $r.Array, [ 1, 5, 42, 13 ], "coercion to Array";
    is-deeply $r.List, ( 1, 5, 42, 13 ), "coercion to List";
}

subtest "Rect/Point interactions" => {
    plan 9;
    my $r = Vikna::Rect.new: 3, 13, 42, 10;
    my @tests =
        "Point left of rect" => {
            p => (1, 14),
            contains => False,
        },
        "Point right of rect" => {
            p => (50, 14),
            contains => False,
        },
        "Point over the rect" => {
            p => (5, 5),
            contains => False,
        },
        "Point under the rect" => {
            p => (5, 30),
            contains => False,
        },
        "Point on rect's left edge" => {
            p => (3, 14),
            contains => True,
        },
        "Point on rect's right edge" => {
            p => (44, 14),
            contains => True,
        },
        "Point on rect's top edge" => {
            p => (5, 13),
            contains => True,
        },
        "Point on rect's bottom edge" => {
            p => (5, 22),
            contains => True,
        },
        "Point is inside the rect" => {
            p => (13, 17),
            contains => True,
        }
        ;
    for @tests -> (:$key, :%value) {
        subtest $key => {
            plan 1;
            is ?$r.contains( |%value<p> ), so %value<contains>, "rect {%value<contains> ?? "do" !! "do not"} contain the point";
        }
    }
}

subtest "Rect interactions" => {
    plan 10;
    my @tests =
        "Covered" => {
            r1 => (5, 5, 10, 12),
            r2 => (3, 3, 42, 21),
            overlap => True,
            dissect => (),
            clip => (5, 5, 10, 12),
        },
        "Left of" => {
            r1 => (5, 5, 10, 12),
            r2 => (21, 3, 42, 21),
            dissect => ((5, 5, 10, 12),),
            clip => (0, 0, 0, 0),
        },
        "Right of" => {
            r1 => (51, 5, 10, 12),
            r2 => (3, 3, 42, 21),
            dissect => ((51, 5, 10, 12,),),
            clip => (0, 0, 0, 0),
        },
        "Top of" => {
            r1 => (5, 5, 10, 12),
            r2 => (3, 32, 42, 21),
            dissect => ((5, 5, 10, 12),),
            clip => (0, 0, 0, 0),
            clip => (0, 0, 0, 0),
        },
        "Bottom of" => {
            r1 => (5, 32, 10, 12),
            r2 => (3, 3, 42, 21),
            dissect => ((5, 32, 10, 12),),
            clip => (0, 0, 0, 0),
        },
        "Overlay 1" => {
            r1 => (0, 0, 3, 3),
            r2 => (1, 1, 1, 1),
            overlap => True,
            dissect => ((0, 0, 1, 3), (2, 0, 1, 3), (1, 0, 1, 1), (1, 2, 1, 1)),
            clip => (1, 1, 1, 1),
        },
        "Overlay 2" => {
            r1 => (3, 3, 42, 21),
            r2 => (5, 5, 10, 12),
            overlap => True,
            dissect => ((3, 3, 2, 21), (15, 3, 30, 21), (5, 3, 10, 2), (5, 17, 10, 7)),
            clip => (5, 5, 10, 12),
        },
        "Overlap left" => {
            r1 => (0, 2, 5, 2),
            r2 => (2, 0, 10, 5),
            overlap => True,
            dissect => ((0, 2, 2, 2),),
            clip => (2, 2, 3, 2),
        },
        "Overlap left top" => {
            r1 => (0, 0, 10, 5),
            r2 => (2, 2, 10, 5),
            overlap => True,
            dissect => ((0, 0, 2, 5), (2, 0, 8, 2)),
            clip => (2, 2, 8, 3),
        },
        "Overlap right bottom" => {
            r1 => (2, 2, 10, 5),
            r2 => (0, 0, 10, 5),
            overlap => True,
            dissect => ((10, 2, 2, 5), (2, 5, 8, 2)),
            clip => (2, 2, 8, 3),
        },
        ;

    for @tests -> (:$key, :%value) {
        subtest $key => {
            plan 3;
            my $r1 = Vikna::Rect.new: |%value<r1>;
            is ?$r1.overlap( |%value<r2> ), so %value<overlap>, "{ %value<overlap> ?? "" !! "do not " } overlap";
            is-deeply $r1.dissect( |%value<r2> ).map( *.List ), %value<dissect>, "dissected correctly";
            is-deeply $r1.clip( |%value<r2> ).List, %value<clip>, "clipped rectangle";
        }
    }
}

done-testing;
