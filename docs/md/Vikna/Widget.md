NAME
====



`Vikna::Widget` - the basic one

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md), [`Vikna::Object`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Object.md), [`Vikna::Parent`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Parent.md), [`Vikna::Child`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Child.md), [`Vikna::EventHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/EventHandling.md), [`Vikna::CommandHandling`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/CommandHandling.md), [`Vikna::Rect`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Rect.md), [`Vikna::Events`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Events.md), [`Vikna::Color`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Coloe.md), [`Vikna::Canvas`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Canvas.md), [`Vikna::Utils`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Utils.md), [`Vikna::WAttr`](https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/WAttr.md), [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

### has Vikna::Rect $.viewport

Visible part of the widget relative to the parent.

### has Vikna::Rect $.abs-geom

Rectange in absolute coordinates of the top widget (desktop)

### has Vikna::Rect $.abs-viewport

Visible rectange of the vidget in it's parent in absolute coords.

