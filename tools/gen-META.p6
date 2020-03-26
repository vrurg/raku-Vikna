#!/usr/bin/env raku

use lib <lib>;
use META6;
use Vikna;

my $m = META6.new(
    name           => 'Vikna',
    description    => 'Console UI toolkit',
    version        => Vikna.^ver,
    perl-version   => Version.new('6.e'),
    depends        => qw“Template::Mustache
                         DB::SQLite
                         Terminal::Print
                         AttrX::Mooish:ver<0.7.3+>
                         Color
                         Color::Names
                         Concurrent::Queue”,
    test-depends   => <Test Test::META Test::When>,
    build-depends  => <Pod::To::Markdown>,
    tags           => <Vikna UI console>,
    authors        => ['Vadim Belman <vrurg@cpan.org>'],
    auth           => 'github:vrurg',
    source-url     => 'git://github.com/vrurg/raku-Vikna.git',
    support        => META6::Support.new(
        source          => 'git://github.com/vrurg/raku-Vikna.git',
    ),
    provides => {
        'Vikna::App' => 'lib/Vikna/App.rakumod',
    },
    resources => [ 'tracer/html.tmpl' ],
    license        => 'Artistic-2.0',
    production     => True,
);

print $m.to-json;
