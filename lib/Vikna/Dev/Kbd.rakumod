use v6.e.PREVIEW;
unit module Vikna::Dev::Kbd;

enum ControlKeys is export <
    K_F1 K_F2 K_F3 K_F4 K_F5 K_F6 K_F7 K_F8 K_F9 K_F10 K_F11 K_F12 K_F13 K_F14 K_F15 K_F16 K_F17 K_F18 K_F19 K_F20
    K_Enter K_Ins K_Del K_Backspace K_Tab K_ScrLock K_Break
    K_Home K_Begin K_End K_PgUp K_PgDn
    K_Up K_Down K_Left K_Right
    KP_Minus KP_Plus KP_Star KP_Period KP_Comma KP_Slash KP_Equal
    KP_0 KP_1 KP_2 KP_3 KP_4 KP_5 KP_6 KP_7 KP_8 KP_9
    KP_Space KP_Tab KP_Enter
>;

enum ModifierKeys is export <K_Shift K_Alt K_Control K_Meta>;
