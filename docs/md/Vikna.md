NAME
====

`Vikna` – all native event-driven Raku console UI

SYNOPSIS
========



    use Vikna::App;
    use Vikna::Window;
    use Vikna::Button;
    use Vikna::Event;

    class MyWin is Vikna::Window {
        multi method event(Event::Button::Click:D $ev) {
            $.desktop.quit;
        }
    }

    class MyApp is Vikna::App {
        method main {
            my $w = $.desktop.create-child: Vikna::Window,
                                            :x(5), :y(5), :w(20), :h(10),
                                            :name('MainWin'), :title('Main Window');
            $w.create-child: Vikna::Button, :x(1), :y(1), :text("Quit"), :target($w);
        }
    }

    MyApp.run;

DESCRIPTION
===========



SEE ALSO
========

[`Vikna::Manual`](https://github.com/vrurg/raku-Test-Async/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Widget`](https://github.com/vrurg/raku-Test-Async/blob/v0.0.1/docs/md/Vikna/Widget.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

