use v6.e.PREVIEW;
unit class Vikna::Object;

use Vikna::X;
use AttrX::Mooish;
use Hash::Merge;

my class CodeFlow {
    has UInt $.id;
    has Str:D $.name is rw = "*anon*";
    has Promise $.promise is rw;
}

has $.app;
has Int $.id is mooish(:lazy);
has $!name is mooish(:lazy);

multi method new(*%c) {
    nextwith |self.make-object-profile(%c);
}

method make-object-profile(%c) {
    my %config;
    with %c<app> {
        %config = .profile-config(self.^name, %c<name>)
    }
    my %default;
    self.WALK(:name<profile-default>, :!methods, :roles).reverse.()
        .map({ merge-hash %default, %$_, :no-append-array });
    # .trace: "Default profile for ", self.^name, "::new\n", %default.map({ .key ~ " => " ~ (.value ~~ Vikna::Object ?? .value.WHICH !! .value.raku) }).join("\n")
    #     with %c<app>;
    my %profile;
    self.WALK(:name<profile-checkin>, :!methods, :roles).reverse.(%profile, %c, %default, %config);
    # .trace: "Profile for ", self.^name, "::new\n", %profile.map({ .key ~ " => " ~ (.value ~~ Vikna::Object ?? .value.WHICH !! .value.raku) }).join("\n")
    #     with %c<app>;
    %profile
}

submethod profile-default { %() }

submethod profile-checkin(%profile, %constructor, %default, %config) {
    # .trace: "Profile checking for ", self.^name, "\n- constructor:\n",
    #     %constructor.map({ "  . " ~ .key ~ " => " ~ (.value ~~ Vikna::Object ?? .value.WHICH !! .value.raku) ~ "\n" }),
    #     "- default:\n",
    #     %default.map({ "  . " ~ .key ~ " => " ~ (.value ~~ Vikna::Object ?? .value.WHICH !! .value.raku) ~ "\n" })
    #     with %constructor<app>;
    merge-hash(%profile, %default,     :no-append-array);
    merge-hash(%profile, %config,      :no-append-array);
    merge-hash(%profile, %constructor, :no-append-array);
}

method build-id {
    use nqp;
    nqp::objectid(self)
}

method !build-name {
    self.^name ~ "<" ~ $.id ~ ">"
}

multi method name(::?CLASS:D:) { $!name }
multi method name(::?CLASS:U:) { self.^name }

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

method flow(&code, Str :$name?, :$sync = False, :$branch = False) {
    my $flow = $branch ?? $*VIKNA-FLOW !! $.allocate-flow(:$name);

    my sub flow-start {
        my $*VIKNA-FLOW = $flow;
        LEAVE { $.free-flow($flow) unless $branch };
        &code();
    }

    if $sync {
        Promise.kept(flow-start);
    }
    else {
        ( $flow.promise = Promise.start(&flow-start) ).then: {
            my $*VIKNA-FLOW = $flow;
            if .status ~~ Broken {
                self.trace: "FLOW BROKEN: " ~ .cause, ~.cause.backtrace, :error;
                note "===FLOW `{$name}` PANIC!=== ", .cause.message, .cause.backtrace.Str;
                self.panic(.cause);
                .cause.rethrow;
            }
        };
    }
}

method panic(Exception:D $cause) {
    note "===PANIC!=== On object ", self.?name // self.WHICH, "\n", $cause.message, ~$cause.backtrace;
    exit 1;
}

multi method Str { self.name }
