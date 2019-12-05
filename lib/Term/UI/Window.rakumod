use v6;
use Term::UI::Widget;
use Term::UI::Window::Border;
unit class Term::UI::Window is Term::UI::Widget is export;

use Term::UI::Events;

my class Client is Term::UI::Widget { }

has Str:D $.title = "";
has $.border;
has Client $.client handles <add-child remove-child to-top to-bottom create-child>;

submethod TWEAK(Bool:D :$border = True) {
    my ($cx, $cy, $cw, $ch) = (0, 0, self.w, self.h);
    if $border {
        $!border = Term::UI::Window::Border.new:
                        :w( $cw ), :h( $ch ), :x(0), :y(0),
                        :app( self.app ), :owner( self );
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    $!client = Client.new:
                    :x( $cx ), :y( $cy ), :w( $cw ), :h( $ch ),
                    :app( self.app ), :owner( self ),
                    :bg-pattern('.-+'), :bg-color('on_blue'),
                    :auto-clear( self.auto-clear );
}

method set-title(Str:D $!title) {
    self.dispatch: Event::TitleChange
}

method clear {
    $!client.clear;
}

method redraw {
    my $grid = self.begin-draw;
    $!border.redraw;
    $!client.redraw;
    self.?draw( :$grid );
    self.end-draw( :$grid );
}

method resize(Int:D :$w is copy where * > 0 = $.w, Int:D :$h is copy where * > 0 = $.h) {
    my $minh = my $minw = $!border ?? 4 !! 2;
    $w = $minw if $w < $minw;
    $h = $minh if $h < $minh;
    nextwith(:$w, :$h)
}

method composite {
    with $.grid {
        $!border.composite: to => $_;
        $!client.composite: to => $_;
    }
    nextsame
}

multi method event(Event::TitleChange:D) {
    self.redraw;
}

multi method event(Event::Resize:D $ev) {
    $!client.resize(:w($.w - 2), :h($.h - 2));
    $!border.resize(:$.w, :$.h);
    self.redraw;
}
