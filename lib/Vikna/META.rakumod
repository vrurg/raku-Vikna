# This module is only used for distribution build

unit module Vikna::META;
use META6;

our sub META6 is raw {
    name => 'Vikna',
    description => 'Console UI toolkit',
    perl-version => Version.new('6.e'),
    raku-version => Version.new('6.e'),
    tags => <ASYNC ASYNCHRONOUS UI CONSOLE TEXT>,
    depends => qw[Template::Mustache
                         DB::SQLite
                         Terminal::Print
                         AttrX::Mooish:ver<0.7.3+>
                         Color
                         Color::Names
                         Cache::Async
                         Concurrent::PChannel
                         Hash::Merge],
    test-depends => <Test Test::Async Test::META>,
    tags => <Vikna UI console>,
    authors => ['Vadim Belman <vrurg@cpan.org>'],
    auth => 'github:vrurg',
    source-url => 'https://github.com/vrurg/raku-Vikna.git',
    support => META6::Support.new(source => 'https://github.com/vrurg/raku-Vikna'),
    provides => {
        'Vikna' => 'lib/Vikna.rakumod',
        'Vikna::App' => 'lib/Vikna/App.rakumod',
        'Vikna::Border' => 'lib/Vikna/Border.rakumod',
        'Vikna::Button' => 'lib/Vikna/Button.rakumod',
        'Vikna::Canvas' => 'lib/Vikna/Canvas.rakumod',
        'Vikna::CAttr' => 'lib/Vikna/CAttr.rakumod',
        'Vikna::Child' => 'lib/Vikna/Child.rakumod',
        'Vikna::Color' => 'lib/Vikna/Color.rakumod',
        'Vikna::Color::Index' => 'lib/Vikna/Color/Index.rakumod',
        'Vikna::Color::Named' => 'lib/Vikna/Color/Named.rakumod',
        'Vikna::Color::RGB' => 'lib/Vikna/Color/RGB.rakumod',
        'Vikna::Color::RGBA' => 'lib/Vikna/Color/RGBA.rakumod',
        'Vikna::CommandHandling' => 'lib/Vikna/CommandHandling.rakumod',
        'Vikna::Coord' => 'lib/Vikna/Coord.rakumod',
        'Vikna::Dev::Kbd' => 'lib/Vikna/Dev/Kbd.rakumod',
        'Vikna::Dev::Mouse' => 'lib/Vikna/Dev/Mouse.rakumod',
        'Vikna::Desktop' => 'lib/Vikna/Desktop.rakumod',
        'Vikna::Elevatable' => 'lib/Vikna/Elevatable.rakumod',
        'Vikna::EventEmitter' => 'lib/Vikna/EventEmitter.rakumod',
        'Vikna::EventHandling' => 'lib/Vikna/EventHandling.rakumod',
        'Vikna::Events' => 'lib/Vikna/Events.rakumod',
        'Vikna::Focusable' => 'lib/Vikna/Focusable.rakumod',
        'Vikna::InputLine' => 'lib/Vikna/InputLine.rakumod',
        'Vikna::Label' => 'lib/Vikna/Label.rakumod',
        'Vikna::Object' => 'lib/Vikna/Object.rakumod',
        'Vikna::OS' => 'lib/Vikna/OS.rakumod',
        'Vikna::OS::unix' => 'lib/Vikna/OS/unix.rakumod',
        'Vikna::Parent' => 'lib/Vikna/Parent@.r@aku@mo@d',
        'Vikna::Point' => 'lib/Vikna/Point@.r@rak@umod',
        'Vikna::PointerTarget' => 'lib/Vikna/PointerTarget.rakumod',
        'Vikna::Rect' => 'lib/Vikna/Rect.rakumod',
        'Vikna::Screen' => 'lib/Vikna/Screen.rakumod',
        'Vikna::Screen::ANSI' => 'lib/Vikna/Screen/ANSI.rakumod',
        'Vikna::Scrollable' => 'lib/Vikna/Scrollable.rakumod',
        'Vikna::Test' => 'lib/Vikna/Test.rakumod',
        'Vikna::Test::App' => 'lib/Vikna/Test/App.rakumod',
        'Vikna::Test::OS' => 'lib/Vikna/Test/OS.rakumod',
        'Vikna::Test::Screen' => 'lib/Vikna/Test/Screen.rakumod',
        'Vikna::TextScroll' => 'lib/Vikna/TextScroll.rakumod',
        'Vikna::Tracer' => 'lib/Vikna/Tracer.rakumod',
        'Vikna::Utils' => 'lib/Vikna/Utils.rakumod',
        'Vikna::WAttr' => 'lib/Vikna/WAttr.rakumod',
        'Vikna::Widget' => 'lib/Vikna/Widget.rakumod',
        'Vikna::Widget::Group' => 'lib/Vikna/Widget/Group.rakumod',
        'Vikna::Widget::GroupMember' => 'lib/Vikna/Widget/GroupMember.rakumod',
        'Vikna::Window' => 'lib/Vikna/Window.rakumod',
        'Vikna::X' => 'lib/Vikna/X.rakumod',
    },
    resources => [
        'tracer/html.tmpl',
        'tracer/txt.tmpl',
        'color-index.json',
    ],
    license => 'Artistic-2.0',
    production => True,
}
