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



This framework is an attempt to provide a full-fledged console UI for [Raku](https://raku.org). It aims at few primary targets:

  * Be a multi-platform. This is achieved by:

    * being a pure Raku, i.e. avoid use of any native libraries

    * being OS-independent by incapsulating any OS-specific logic in a driver-like layer

  * Support fully asynchronous model of development

Any other implementation specifics of the framework are decisions taken to meet the above targets.

More information can be found in the following sections:

  * [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md)

  * [`Vikna::Classes`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Classes.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

