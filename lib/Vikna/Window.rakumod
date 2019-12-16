use v6.e.PREVIEW;
use Vikna::Widget;
use Vikna::Window::Border;
unit class Vikna::Window is Vikna::Widget is export;

use Vikna::Events;

my class Client is Vikna::Widget {
    method fit {
        my ($w, $h) = $.owner.client-size;
        self.Vikna::Widget::resize(:$w, :$h)
    }
    # Don't allow voluntary client size change.
    method resize { }
}

has Str:D $.title = "";
has $.border;
has Client $.client handles <add-child remove-child to-top to-bottom create-child>;

submethod TWEAK(Bool:D :$border = True) {
    my ($cx, $cy, $cw, $ch) = (0, 0, self.w, self.h);
    if $border {
        $!border = Vikna::Window::Border.new:
                        :w( $cw ), :h( $ch ), :x(0), :y(0),
                        :app( self.app ), :owner( self );
        ++$cx; ++$cy;
        $cw -= 2;
        $ch -= 2;
    }
    $!client = Client.new:
                    :x( $cx ), :y( $cy ), :w( $cw ), :h( $ch ),
                    :app( self.app ), :owner( self ),
                    :bg-pattern('.-+'), :color<black blue>,
                    :auto-clear( self.auto-clear );
}

method set-title(Str:D $title) {
    my $old-title = $!title;
    $!title = $title;
    self.dispatch: Event::TitleChange, :$old-title, :$title
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

method client-size {
    my $bw = $!border ?? 2 !! 0;
    ($.w - $bw, $.h - $bw)
}

method resize(Int:D :$w is copy where * > 0 = $.w, Int:D :$h is copy where * > 0 = $.h) {
    my $min = $!border ?? 4 !! 2;
    $w max= $min;
    $h max= $min;
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
    $!client.fit;
    $!client.resize(:w($.w - 2), :h($.h - 2));
    $!border.resize(:$.w, :$.h);
    self.redraw;
}
