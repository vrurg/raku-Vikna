use v6.e.PREVIEW;

use Vikna::App;
use Vikna::Window;
use Vikna::Label;
use Vikna::InputLine;

class IApp is Vikna::App {
    method main {
        my $iw = $.desktop.create-child:
                        Vikna::Window,
                        :5x, :3y, :60w, :7h,
                        :name<InputWin>,
                        ;
        for ^2 -> $field {
            $iw.create-child:
                            Vikna::Label,
                            :1x, :y( $field*2 + 1 ), :10w,
                            :text("Field $field:")
                            ;
            my $in = $iw.create-child:
                            Vikna::InputLine,
                            :12x, :y( $field*2 + 1 ),
                            :name("Field" ~ $field),
                            ;
        }
    }
}

IApp.new( :!debugging ).run;
