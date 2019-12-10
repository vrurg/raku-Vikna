use v6;
unit package Vikna;
role Event is export {
    has $.origin is required; # Originating object
    has Bool:D $.cleared = False;

    method clear {
        $!cleared = True;
    }
}

role Event::Control does Event is export { }

role Event::TitleChange does Event::Control is export {
    has $.old-title;
    has $.title;
}

role Event::ColorChange does Event::Control is export {
    has $.old-fg;
    has $.old-bg;
    has $.fg;
    has $.bg;
}

role Event::Geom does Event::Control is export { }

role Event::Size does Event::Geom is export {
    has $.old-w;
    has $.old-h;
    has $.w;
    has $.h;
}

role Event::Move does Event::Geom is export {
    has $.old-x;
    has $.old-y;
    has $.x;
    has $.y;
}

class Event::ScreenResize does Event::Size is export { }

class Event::Resize does Event::Size is export { }

class Event::ScrollPosition does Event::Move is export { }

role Event::Kbd does Event is export { }

class Event::KeyPressed does Event::Kbd is export { }
