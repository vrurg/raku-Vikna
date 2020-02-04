use v6.e.PREVIEW;
unit class Vikna::Object;

use Vikna::X;
use AttrX::Mooish;

my class CodeFlow {
    has UInt $.id;
    has Str:D $.name is rw = "*anon*";
    has Promise $.promise is rw;
}

has $.app;
has Int $.id is mooish(:lazy);

method build-id {
    use nqp;
    nqp::objectid(self)
}

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
    fail exception.new( :obj(self), |%args )
}

multi method create(Mu \type, |c) {
    with $!app {
        .create: type, :$!app, |c
    }
    else {
        type.new: |c
    }
}

method trace(|c) {
    with $!app {
        .trace: :obj(self), |c
    }
}

my @flows;
my Lock:D $flow-lock .= new;
method allocate-flow(Str :$name?) {
    $flow-lock.protect: {
        my $id;
        for ^Inf {
            unless @flows[$_].defined {
                $id = $_;
                last
            }
        }
        @flows[$id] = CodeFlow.new: :$id, :$name;
    }
}

method free-flow(CodeFlow:D $flow) {
    $flow-lock.protect: {
        @flows[$flow.id]:delete
    }
}

method flow(&code, Str :$name?, :$sync = False) {
    my $flow = $.allocate-flow(:$name);

    sub flow-start {
        my $*VIKNA-FLOW = $flow;
        LEAVE $.free-flow($flow);
        &code();
    }

    if $sync {
        Promise.kept(flow-start);
    }
    else {
        ( $flow.promise = Promise.start(&flow-start) ).then: {
            my $*VIKNA-FLOW = $flow;
            if .status ~~ Broken {
                $.trace: "FLOW BROKEN: " ~ .cause, ~.cause.backtrace, :error;
                note "===FLOW `{$name}` PANIC!=== ", .cause.message, .cause.backtrace.Str;
                self.panic(.cause);
                .cause.rethrow;
            }
        };
    }
}

method panic(Exception:D $cause) {
    my $bail-out = True;
    if $.app {
        $.app.desktop.dismissed.then: { $bail-out = False; };
        await Promise.anyof(
            Promise.in(10),
            start $.app.panic($cause, :object(self))
        );
    }
    else {
        note "===PANIC!=== On object ", self.?name // self.WHICH, "\n", $cause.message, ~$cause.backtrace;
    }
    exit 1 if $bail-out;
}
