use v6.e.PREVIEW;
use Vikna::Color;

unit class Vikna::Color::RGB does Vikna::Color;

method Str {
    my @chan = $.r, $.g, $.b;
    # @chan.push: $_ with $.a;
    join(",", @chan)
}
