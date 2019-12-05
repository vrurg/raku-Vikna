use v6;
use Term::UI::Scrollable;
use Term::UI::Widget;
unit class Term::UI::TextScroll;
also does Term::UI::Scrollable;
also is Term::UI::Widget;

use Term::UI::Events;

class Event::BufChange does Event::Control is export {
    has $.old-size;
    has $.size;
}

my class BufLine {
    has $.str = "";
    has $.pos is rw = 0;

    method nl {
        $!str.substr(*-1,1) ~~ /\n/
    }

    method imprint(Str:D() $str) {
        if ($!pos - $!str.chars) -> $d {
            $!str ~= " " x $d
        }
        my $slen;
        $!str.substr-rw($!pos, $slen = $str.chars) = $str;
        $!pos += $slen;
        self
    }

    method substr($pos, $count) {
        $!str.chars < $pos ?? "" !! $!str.substr($pos,$count);
    }
}

has @.buffer = [ BufLine.new ];
has $!cur-row = 0;
has Int:D $.buffer-size = 200;
has Bool:D $!wrap = True;
has Bool:D $.auto-scroll = True;

method cur-line(--> BufLine) { @!buffer[$!cur-row] }
method next-line {
    @!buffer.push: BufLine.new if @!buffer <= ++$!cur-row;
    @!buffer[$!cur-row]
}

method add-text(Str:D $text is copy) {
    my $old-size = @!buffer.elems;

    my $do-scroll = $!auto-scroll && ($.dy + $.h) >= $.lines;

    $text ~~ s:g/\x1B/^[/;

    my $text-width = $!wrap ?? $.w !! Inf;
    my $max-cols = $.columns;

    while $text {
        my $m = $text ~~ s/$<line>=[ \N ** {0..$text-width} ] [ $<nl>=\n ]?//;
        my $cur-line = $.cur-line.imprint($m<line>);

        my $line-length = $cur-line.str.chars;
        $max-cols = $line-length if $max-cols < $line-length;

        given $m<nl> {
            when Nil { }
            when "\c[VERTICAL TABULATION]" | "\c[FORM FEED]" {
                $.next-line.pos = $m<line>.chars;
                $cur-line.imprint($m<nl>);
            }
            when "\c[CARRIAGE RETURN]" {
                $.cur-line.pos = 0;
            }
            default {
                $cur-line.imprint($m<nl>);
                $.next-line;
            }
        }
    }

    @!buffer.splice: 0, (+@!buffer - $!buffer-size) if +@!buffer > $!buffer-size;
    $!cur-row min= @!buffer.end;
    self.set-area: lines => +@!buffer, columns => $max-cols;
    self.set-pos: dy => $.lines - $.h if $do-scroll;

    self.dispatch(Event::BufChange, :$old-size, :size( @!buffer.elems ));
    self
}

method print(**@args) {
    self.add-text: @args.join: ""
}

method say(**@args) {
    self.add-text: (|@args, "\n").join: ""
}

method draw( :$grid ) {
    callsame;
    for $.dy..^($.dy + $.h) -> $lnum {
        my $y = $lnum - $.dy;
        my $out = $lnum < @!buffer ?? @!buffer[$lnum].substr($.dx, $.w) !! "";
        $grid.set-span-text($.dx, $y, $out.chomp);
    }
}
