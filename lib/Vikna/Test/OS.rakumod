use v6.e.PREVIEW;

unit class Vikna::Test::OS;

use Vikna::OS;
use Vikna::Test::Screen;

also does Vikna::OS;

method build-screen {
    Vikna::Test::Screen.new
}

method inputs {
    [
        $.screen
    ]
}
