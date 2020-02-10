use v6.e.PREVIEW;
use Vikna::Scrollable;
use Vikna::Widget;

unit class Vikna::TextScroll;
also does Vikna::Scrollable;
also is Vikna::Widget;

use Vikna::Events;

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

    method append(Str:D() $str) {
        $!str ~= $str;
        $!pos = $!str.chars;
    }

    method substr($pos, $count) {
        $!str.chars < $pos ?? "" !! $!str.substr($pos,$count);
    }
}

has @.buffer is default(BufLine.new);
has $!cur-row = 0;
has Int:D $.buffer-size = 200;
has Bool:D $!wrap = True;
has Bool:D $.auto-scroll = True;

### Command handlers ###

method cmd-textscroll-addtext(Str:D $text is copy) {
    my $old-size = @!buffer.elems;

    # Translate escapes.
    $text ~~ s:g| \x1B | ^[ |;

    $.trace: "&&& CMD ADD-TEXT «$text»";

    my $text-width = $!wrap ?? $.w !! Inf;
    my $max-cols = $.columns;

    while $text {
        my $m = $text ~~ s/$<line>=[ \N ** {0..$text-width} ] [ $<nl>=\n ]?//;
        $.trace: "IMPRINTING LINE ‘{$m<line>}’ into ‘{$.cur-line.str}’:{$.cur-line.pos}";
        my $cur-line = $.cur-line.imprint($m<line>);
        $.trace: "RESULTING LINE: ‘{$cur-line.str}’";

        my $line-length = $cur-line.str.chars;
        $max-cols = $line-length if $max-cols < $line-length;

        given $m<nl> {
            when Nil { }
            when "\c[VERTICAL TABULATION]" | "\c[FORM FEED]" {
                $.trace: "VERTICAL FEED, cur line is: ", $cur-line.str;
                self!next-line.pos = $m<line>.chars;
                $cur-line.imprint($m<nl>);
            }
            when "\c[CARRIAGE RETURN]" {
                $.trace: "CARRIAGE RETURN, cur line is: ", $cur-line.str;
                $cur-line.pos = 0;
            }
            default {
                $.trace: "PRINT «{$m<nl>}» into «{$cur-line.str}»:{$cur-line.pos}";
                $cur-line.append($m<nl>);
                # $.trace: "PRINTED «{$m<nl>}» into «{$cur-line.str}»:{$cur-line.pos}";
                self!next-line;
            }
        }
    }

    $.scroll-transaction: {
        @!buffer.splice: 0, (+@!buffer - $!buffer-size) if +@!buffer > $!buffer-size;
        $!cur-row min= @!buffer.end;
        self!set-area( :w( $max-cols ), :h( +@!buffer ) );
        my $ovflow = $.lines - $.dy - $.h ;
        if $!auto-scroll && $ovflow > 0 {
            $.trace: "SCROLL-BY ", $ovflow;
            self!scroll( dy => $ovflow );
        }
    }
    $.dispatch: Event::TextScroll::BufChange, :$old-size, :size( @!buffer.elems );
    $.invalidate;
    $.redraw;
}

method cmd-scroll-by(Int:D $dx, Int:D $dy) {
    self!scroll($dx, $dy)
}

method cmd-scroll-to(Int $x, Int $y) {
    self!scroll-to($x, $y)
}

method cmd-scroll-setarea($geom) {
    my $from = Vikna::Rect.new(w => $!columns, h => $!lines);
    self!set-area(w => .w, h => .h) with $geom;
    self.dispatch: Event::Scroll::Area, :$from, to => Vikna::Rect.new(w => $!columns, h => $!lines)
        unless $from.w == $!columns && $from.h == $!lines;
}

method cmd-setgeom(|) {
    callsame;
    self!adjust-pos;
}

method cmd-scroll-fit(Bool:D :$width?, Bool:D :$height?) {
    self!fit(:$width, :$height);
    self!adjust-pos
}

### Command senders ###

method add-text(Str:D $text is copy) {
    $.trace: "ADD-TEXT: «$text»";
    self.send-command: Event::Cmd::TextScroll::AddText, $text;
}

method scroll(Int:D $dx = 0, Int:D $dy = 0 ) {
    $.send-command: Event::Cmd::Scroll::By, $dx, $dy;
}

method scroll-to(Int $x, Int $y) {
    $.send-command: Event::Cmd::Scroll::To, $x, $y;
}

method set-area(Int:D :$w where * >= 0, Int:D :$h where * >= 0) {
    self.send-command: Event::Cmd::Scroll::SetArea, Vikna::Rect.new(:0x, :0y, :$w, :$h);
}

#| Set fit flags.
method fit(Bool:D :$width?, Bool:D :$height?) {
    self.send-command: Event::Cmd::Scroll::Fit, :$width, :$height;
}

### Event handlers ###

# multi method event(Event::TextScroll::BufChange:D $ev) {
#     $.trace: "TEXTSCROLL -- REDRAW";
#     $.invalidate;
#     $.redraw;
# }

### Utility methods ###
method cur-line(--> BufLine) {
    $.trace: "CUR ROW: ", $!cur-row, " LINES IN BUFFER: ", +@!buffer;
     @!buffer[$!cur-row]
  }
method !next-line {
    @!buffer.push: BufLine.new if @!buffer <= ++$!cur-row;
    @!buffer[$!cur-row]
}

method print(**@args) {
    $.trace: "TS.PRINT: [[", @args, "]]";
    self.add-text: @args.join: ""
}

method say(**@args) {
    self.add-text: (|@args, "\n").join: ""
}

method draw( :$canvas ) {
    callsame;
    $.trace: "TextScroll draw";
    for $.dy..^($.dy + $.h) -> $lnum {
        my $y = $lnum - $.dy;
        my $out = $lnum < @!buffer ?? @!buffer[$lnum].substr($.dx, $.w) !! "";
        $canvas.imprint($.dx, $y, $out.chomp);
    }
}
