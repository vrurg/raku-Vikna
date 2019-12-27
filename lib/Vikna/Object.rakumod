use v6.e.PREVIEW;
unit class Vikna::Object;

use Vikna::X;

has $.app;

multi method throw(X::Base:D $ex) {
    $ex.rethrow
}

multi method throw( X::Base:U \exception, *%args ) {
    exception.new( :obj(self), |%args ).throw
}

multi method fail( X::Base:D $ex ) {
    fail $ex
}

multi method fail( X::Base:U \exception, *%args ) {
    fail exception.new( |%args )
}

multi method create(Mu \type, |c) {
    with $!app {
        .create: type, :$!app, |c
    }
    else {
        type.new: |c
    }
}

method debug(|c) {
    with $.app {
        .debug: |c
    }
}
