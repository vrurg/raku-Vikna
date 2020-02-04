use v6.e.PREVIEW;
use Red:api<2>;
unit model Vikna::Tracer::Session is table<vikna_session>;

has Int $.id        is id;
has Rat $.started   is column; # Time
has Str $.name      is column;

has @.records is relationship( *.session-id, :model<Vikna::Tracer::Record> );
