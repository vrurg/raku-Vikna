use v6.e.PREVIEW;

unit class Vikna::OS::unix;

use Vikna::OS;
use Vikna::Object;
use Vikna::Events;
use Vikna::EventEmitter;
use Vikna::Dev::Mouse;
use Vikna::Screen::ANSI;

also does Vikna::OS;

my class Input {
    also is Vikna::Object;
    also does Vikna::EventEmitter;
    also does Vikna::Dev::Mouse::EventProcessor;

    use Vikna::Dev::Kbd;
    use Terminal::Print::DecodedInput;

    has Supply $!in-supply;
    has Promise $!closed .= new;

    has Vikna::Point $!last-mouse-pos;

    submethod TWEAK {
        set-mouse-event-mode(AnyEvents);
        $!in-supply = decoded-input-supply;
    }

    my %special-map =
        Backspace           => K_Backspace,
        CursorUp            => K_Up,
        CursorDown          => K_Down,
        CursorRight         => K_Right,
        CursorLeft          => K_Left,
        CursorHome          => K_Home,
        CursorEnd           => K_End,
        CursorBegin         => K_Begin,
        Delete              => K_Del,
        Insert              => K_Ins,
        Home                => K_Home,
        End                 => K_End,
        PageUp              => K_PgUp,
        PageDown            => K_PgDn,
        KeypadSpace         => KP_Space,
        KeypadTab           => KP_Tab,
        KeypadEnter         => KP_Enter,
        KeypadStar          => KP_Star,
        KeypadPlus          => KP_Plus,
        KeypadComma         => KP_Comma,
        KeypadMinus         => KP_Minus,
        KeypadPeriod        => KP_Period,
        KeypadSlash         => KP_Slash,
        KeypadEqual         => KP_Equal,
        Keypad0             => KP_0,
        Keypad1             => KP_1,
        Keypad2             => KP_2,
        Keypad3             => KP_3,
        Keypad4             => KP_4,
        Keypad5             => KP_5,
        Keypad6             => KP_6,
        Keypad7             => KP_7,
        Keypad8             => KP_8,
        Keypad9             => KP_9,
        F1                  => K_F1,
        F2                  => K_F2,
        F3                  => K_F3,
        F4                  => K_F4,
        F5                  => K_F5,
        F6                  => K_F6,
        F7                  => K_F7,
        F8                  => K_F8,
        F9                  => K_F9,
        F10                 => K_F10,
        F11                 => K_F11,
        F12                 => K_F12,
        F13                 => K_F13,
        F14                 => K_F14,
        F15                 => K_F15,
        F16                 => K_F16,
        F17                 => K_F17,
        F18                 => K_F18,
        F19                 => K_F19,
        F20                 => K_F20;

    has %modifier-map = shift => K_Shift, alt => K_Alt, control => K_Control, meta => K_Meta;

    method !translate-special-key(SpecialKey $key) {
        return $_ with %special-map{$key};
        self.throw: X::Input::BadSpecialKey, :$key;
    }

    method !make-modifiers($ev-packet) {
        my @mods;
        for %modifier-map.kv -> $name, $val {
            @mods.push: $val if $ev-packet.?"$name"();
        }
        set(|@mods)
    }

    method init {
        self.flow: :name("UNIX INPUT LOOP"), {
            my $vf = $*VIKNA-FLOW;
            react {
                whenever $!in-supply -> $term-ev {
                    my $*VIKNA-FLOW = $vf;
                    # self.trace: "TERMINAL EVENT: ", $term-ev.^name;
                    given $term-ev {
                        when PasteStart {
                            self.post-event: Event::Screen::PasteStart;
                        }
                        when PasteEnd {
                            self.post-event: Event::Screen::PasteEnd;
                        }
                        when FocusIn {
                            self.post-event: Event::Screen::FocusIn;
                        }
                        when FocusOut {
                            self.post-event: Event::Screen::FocusOut;
                        }
                        when SpecialKey {
                            # self.trace: "Special key into Event::Kbd::Control";
                            self.post-event: Event::Kbd::Control, key => self!translate-special-key($_)
                        }
                        when Terminal::Print::DecodedInput::ModifiedSpecialKey {
                            self.post-event: Event::Kbd::Control,
                                            key         => self!translate-special-key(.key),
                                            modifiers   => self!make-modifiers($_)
                        }
                        when Terminal::Print::DecodedInput::MouseEvent {
                            my \evType := .button && .motion
                                            ?? Event::Mouse::Drag
                                            !! .button
                                                ?? (.pressed ?? Event::Mouse::Press !! Event::Mouse::Release)
                                                !! Event::Mouse::Move;
                            $!last-mouse-pos = Vikna::Point.new: .x, .y;
                            for self.translate-mouse-event(
                                    evType,
                                    at => Vikna::Point.new(.x, .y),
                                    modifiers => self!make-modifiers($_),
                                    prev => $!last-mouse-pos,
                                    button => .button,
                                ) -> \c {
                                self.post-event: |c;
                            }
                        }
                        when .ord == 13 {
                            self.post-event: Event::Kbd::Control, key => K_Enter, char => $_;
                        }
                        when .ord == 9 {
                            self.post-event: Event::Kbd::Control, key => K_Tab, char => $_;
                        }
                        when .ord < 32 {
                            my $char = $_;
                            my $key = (.ord + 64).chr;
                            self.post-event: Event::Kbd::Control, :$key, :$char,
                                            modifiers => set(K_Control);
                        }
                        default {
                            self.post-event: Event::Kbd::Press, :char($_);
                        }
                    }
                }
                whenever $!closed {
                    done
                }
                CATCH {
                    default {
                        $.panic($_);
                        .rerthrow;
                    }
                }
            }
        }
    }

    method shutdown {
        set-mouse-event-mode(NoEvents);
        self.Vikna::EventEmitter::shutdown;
        $!closed.keep(True) if $!closed.status ~~ Planned;
    }

    method panic($cause) {
        self.Vikna::EventEmitter::panic($cause);
        nextsame;
    }
}

method build-screen {
    self.create: Vikna::Screen::ANSI;
}

method inputs {
    [
        $.screen,
        self.create: Input
    ]
}
