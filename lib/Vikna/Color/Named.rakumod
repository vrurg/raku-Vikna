use v6.e.PREVIEW;

use Color::Names;

my %color-data = Color::Names.color-data(<X11 XKCB CSS>);

unit role Vikna::Color::Named;

has Str:D $.name is required;

method rgb-by-name(Str:D $name) {
    return %() unless %color-data{$name}:exists;
    my $crecord = %color-data{$name};
    %( <r g b> Z=> $crecord<rgb><> )
}

method known-color-name($name) {
    # ? self!lookup-name($name)
    %color-data{$name}:exists
}

method Str { $!name }
