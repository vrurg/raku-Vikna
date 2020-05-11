# This module is only used for distribution build

unit module Vikna::META;
use META6;

our sub META6 is raw {
    name           => 'Vikna',
    description    => 'Console UI toolkit',
    perl-version   => Version.new('6.e'),
    depends        => qw“Template::Mustache
                         DB::SQLite
                         Terminal::Print
                         AttrX::Mooish:ver<0.7.3+>
                         Color
                         Color::Names
                         Cache::Async
                         Concurrent::PChannel
                         Hash::Merge”,
    test-depends   => <Test Test::Async Test::META>,
    tags           => <Vikna UI console>,
    authors        => ['Vadim Belman <vrurg@cpan.org>'],
    auth           => 'github:vrurg',
    source-url     => 'https://github.com/vrurg/raku-Vikna.git',
    support        => META6::Support.new(
        source          => 'https://github.com/vrurg/raku-Vikna',
    ),
    provides => {
        'Vikna::App' => 'lib/Vikna/App.rakumod',
    },
    resources => [ 'tracer/html.tmpl' ],
    license        => 'Artistic-2.0',
    production     => True,
}
