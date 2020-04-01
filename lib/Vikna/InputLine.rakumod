use v6.e.PREVIEW;

unit class Vikna::InputLine;

use Vikna::Events;
use Vikna::Widget;
use Vikna::Focusable;
use Vikna::PointerTarget;
use Vikna::Dev::Kbd;
use AttrX::Mooish;

also is Vikna::Widget;
also does Vikna::Focusable;
also does Vikna::PointerTarget;

has Str:D $.text = "";
has Int:D $!shift = 0;
has Int:D $!cur-pos = 0;
has Int:D $!cursor-column = 0;
has Int $!sstep is mooish(:lazy, :clearer);
has Int:D $.shift-step = 3;
has Lock::Async:D $!position-lock .= new;

submethod profile-default {
    attr => {
        :fg<default>, :bg<black>, :style('underline'), :pattern(' '),
    },
    focused-attr => {
        :fg<black>, :bg<white>, :style('bold underline'), :pattern(' '),
    },
    h => 1,
    w => 20,
}

method build-sstep {
    $!shift-step < $.w ?? $!shift-step !! $.w;
}

### Event handlers ###

multi method event(Event::Mouse::Click:D $ev) {
    $.focus;
    nextsame
}

multi method event(Event::Focus::In:D $ev) {
    self!set-cursor-position;
    $.show-cursor;
    $.invalidate;
    $.cmd-redraw;
    nextsame
}

multi method event(Event::Focus::Out:D $ev) {
    $.hide-cursor;
    $.invalidate;
    $.cmd-redraw;
    nextsame
}

multi method event(Event::Changed::Geom:D $) {
    self!clear-sstep;
    nextsame;
}

multi method event(Event::Kbd::Control:D $ev) {
    given $ev.key {
        when K_Right {
            $.move-right;
        }
        when K_Left {
            $.move-left;
        }
        when K_Backspace {
            if $!cur-pos > 0 {
                my $text = $!text.substr(0, $!cur-pos - 1) ~ $!text.substr($!cur-pos);
                if $.text-valid($text) {
                    $!text = $text;
                    $.move-left;
                }
            }
        }
        when K_Del {
            if $!cur-pos < $!text.chars {
                my $text = $!text.substr(0, $!cur-pos) ~ $!text.substr($!cur-pos + 1);
                if $.text-valid($text) {
                    $!text = $text;
                    $.invalidate;
                    $.cmd-redraw;
                }
            }
        }
    }
}

multi method event(Event::Kbd::Press:D $ev) {
    if $.char-valid: $ev.char {
        my $text = $!text.substr(0, $!cur-pos) ~ $ev.char ~ $!text.substr($!cur-pos);
        if $.text-valid($text) {
            $!text = $text;
            $.move-right;
        }
    }
}

### Utility methods ###

method draw(:$canvas) {
    $.draw-background(:$canvas);
    if $!text.chars {
        $canvas.imprint(0, 0, $!text.substr($!shift, $.w), $.attr);
    }
    else {
        $canvas.imprint: 0, 0, "Input text here...", |$.attr.Profile, :fg('100,100,100');
    }
}

method !set-cursor-position {
    $.cursor($!cursor-column, 0);
}

method !update-cursor {
    while ($!cur-pos - $!shift) >= $.w {
        if ($!shift += $!sstep) >= $!text.chars {
            $!shift = $!text.chars - $!sstep;
        }
    }
    while ($!cur-pos - $!shift) < 0 {
        if ($!shift -= $!sstep) < 0 {
            $!shift = 0;
        }
    }
    $.cursor: ($!cursor-column = $!cur-pos - $!shift), 0;
    $.invalidate;
    if $*VIKNA-EVQ-OWNER eq self {
        $.cmd-redraw;
    }
    else {
        $.redraw;
    }
}

method move-right {
    $!position-lock.protect: {
        ++$!cur-pos if $!cur-pos < $!text.chars;
        self!update-cursor;
    }
}

method move-left {
    $!position-lock.protect: {
        --$!cur-pos if $!cur-pos;
        self!update-cursor;
    }
}

method char-valid(Str:D $c) {
    $c.chars == 1 && $c ~~ /<print>/
}

method text-valid(Str:D $text) {
    True
}
