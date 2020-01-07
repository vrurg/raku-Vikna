use v6.e.PREVIEW;
unit role Vikna::Belongable[::OwnerType] is export;

use AttrX::Mooish;

has OwnerType $.owner is mooish(:lazy);

method build-owner {
    $.parent // OwnerType
}
