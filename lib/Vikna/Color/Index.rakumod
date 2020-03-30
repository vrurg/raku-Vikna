use v6.e.PREVIEW;

unit role Vikna::Color::Index;

use JSON::Fast;
use AttrX::Mooish;

has Int $.index;

my $color-idx;

my sub color-idx {
    $color-idx //= from-json %?RESOURCES<color-index.json>.slurp;
}

method rgb-by-index(Int:D $idx) {
    my %rgb;
    with color-idx.[$idx] {
        %rgb = .<rgb>
    }
    %rgb
}

method Str { ~$!index }
