use v6.e.PREVIEW;
use Vikna::Object;

unit role Vikna::OS;
also is Vikna::Object;

use Vikna::Screen;

use AttrX::Mooish;

has Vikna::Screen $.screen is mooish(:lazy);

method build-screen { ... }
method inputs {...}
