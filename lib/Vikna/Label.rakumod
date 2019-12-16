use v6.e.PREVIEW;
use Text::UI::Widget;
unit class Text::UI::Label;
also does Text::UI::Widget;

has Str:D $.text is required;
has Str:D $.l-pad = ' ';
has Str:D $.r-pad = ' ';

method draw( :$grid ) {

}
