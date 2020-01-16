use v6.e.PREVIEW;
use Red:api<2>;
unit model Vikna::Tracer::Record is table<vikna_record>;
use Vikna::Tracer::Session;

has UInt $.id           is id;
has Rat  $.time         is column;
has Int  $.flow         is column;
has Str  $.flow-name    is column;
has Str  $.object-id    is column;
has Str  $.message      is column;
has Str  $.class        is column; # Record class like shutdown, etc.
has UInt $.session-id   is referencing( *.id, :model<Vikna::Tracer::Session> );

has      $.session      is relationship( *.session-id, :model<Vikna::Tracer::Session> );
