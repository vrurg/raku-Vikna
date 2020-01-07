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

method cmd-textscroll-addtext(Event::Cmd::TextScroll::AddText:D $ev) {
    my $old-size = @!buffer.elems;

    # Translate escapes.
    my $text = S:g| \x1B | ^[ | given $ev.text;

    $.debug: "&&& CMD ADD-TEXT «$text»";

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
                self!next-line.pos = $m<line>.chars;
                $cur-line.imprint($m<nl>);
            }
            when "\c[CARRIAGE RETURN]" {
                $.cur-line.pos = 0;
            }
            default {
                $cur-line.imprint($m<nl>);
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
            $.debug: "SCROLL-BY ", $ovflow;
            self!scroll( dy => $ovflow );
        }
    }
    $.dispatch: Event::TextScroll::BufChange, :$old-size, :size( @!buffer.elems );
}

method cmd-scroll-by(Event::Cmd::Scroll::By:D $ev) {
    $.debug: "^^^ scroll-by";
    self!scroll(.dx, .dy) with $ev;
}

method cmd-scroll-to(Event::Cmd::Scroll::To:D $ev) {
    self!scroll-to(.x, .y) with $ev;
}

method cmd-scroll-setarea(Event::Cmd::Scroll::SetArea:D $ev) {
    my $from = Vikna::Rect.new(w => $!columns, h => $!lines);
    self!set-area(w => .w, h => .h) with $ev.geom;
    self.dispatch: Event::Scroll::Area, :$from, to => Vikna::Rect.new(w => $!columns, h => $!lines)
        unless $from.w == $!columns && $from.h == $!lines;
}

method cmd-setgeom(Event::Cmd::SetGeom:D $ev) {
    callsame;
    self!adjust-pos;
}

method cmd-scroll-fit(Event::Cmd::Scroll::Fit:D $ev) {
    self!fit(width => .width, height => .height) with $ev;
    self!adjust-pos
}

### Command senders ###

method add-text(Str:D $text is copy) {
    $.debug: "ADD-TEXT: «$text»";
    self.dispatch: Event::Cmd::TextScroll::AddText, :$text;
}

method scroll(Int:D :$dx = 0, Int:D :$dy = 0 ) {
    $.dispatch: Event::Cmd::Scroll::By, :$dx, :$dy;
}

method scroll-to(Int $x, Int $y) {
    $.dispatch: Event::Cmd::Scroll::To, :$x, :$y;
}

method set-area(Int:D :$w where * >= 0, Int:D :$h where * >= 0) {
    self.dispatch: Event::Cmd::Scroll::SetArea, geom => Vikna::Rect.new(:0x, :0y, :$w, :$h);
}

#| Set fit flags.
method fit(Bool:D :$width?, Bool:D :$height?) {
    self.dispatch: Event::Cmd::Scroll::Fit, :$width, :$height;
}

### Event handlers ###

multi method event(Event::TextScroll::BufChange:D $ev) {
    $.debug: "TEXTSCROLL -- REDRAW";
    $.invalidate;
    $.redraw;
}

### Utility methods ###
method cur-line(--> BufLine) {
    $.debug: "CUR ROW: ", $!cur-row, " LINES IN BUFFER: ", +@!buffer;
     @!buffer[$!cur-row]
  }
method !next-line {
    @!buffer.push: BufLine.new if @!buffer <= ++$!cur-row;
    @!buffer[$!cur-row]
}

method print(**@args) {
    $.debug: "TS.PRINT: [[", @args, "]]";
    self.add-text: @args.join: ""
}

method say(**@args) {
    self.add-text: (|@args, "\n").join: ""
}

method draw( :$canvas ) {
    callsame;
    $.debug: "TextScroll draw";
    for $.dy..^($.dy + $.h) -> $lnum {
        my $y = $lnum - $.dy;
        my $out = $lnum < @!buffer ?? @!buffer[$lnum].substr($.dx, $.w) !! "";
        $canvas.imprint($.dx, $y, $out.chomp);
    }
}
