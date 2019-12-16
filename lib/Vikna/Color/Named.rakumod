use v6.e.PREVIEW;
use Vikna::Color;

unit class Vikna::Color::Named does Vikna::Color;

has Str:D $.name is required;

method new(*%c) {
    self.bless(|%c)
}

method Str { $!name }
