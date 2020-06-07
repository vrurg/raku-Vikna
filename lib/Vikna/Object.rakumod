use v6.e.PREVIEW;

=begin pod
=NAME
C<Vikna::Object> - the base class of most of C<Vikna> classes

=DESCRIPTION

This class implements the basic functionality required by many of C<Vikna> classes.

=ATTRIBUTES

=head2 C<$.app>

The application this object has been created under. For example, a typical access to the desktop object is done via:

    $.app.desktop

=head2 C<Int $.id>

Integer unique object id. Implementation dependant and thus one can't rely upon its current implementation. Only makes
sense in object comparison, caching, etc.

Lazy, built by C<build-id> method. See L<C<AttrX::Mooish>|https://modules.raku.org/dist/AttrX::Mooish:cpan:VRURG>.

=METHODS

=head2 C<new(*%c)>

Acts more as a wrapper to the standard method new. This is where profiles are merged and the result is then used to
call the standard C<new> method.

=head2 C<create(Mu \type, |c)>

This method has to be used by any C<Vikna::Object> descendant to create a new Vikna object. The method guarantees that
the application object will be propagated to all newly created instances.

=head2 C<make-object-profile(%c)>

This method implements the magic of object profiles. But before getting into details, I recommend to read about RMRO in
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md> unless already done so.

The argument is the profile as it is supplied to the constructor.

In details, the method:

=item requests for configuration profile from the application object if known;
=item walks over C<profile-default> submethods in reverse RMRO order and collects default profiles. Then merges them into
a single default profile hash;
=item walks over C<profile-checkin> submethods in reverse RMRO order and invokes them with the destination profile hash
object, constructor-supplied profile hash, the merged default profile, and config

The hashes are merged using deep merge as implemented by C<Hash::Merge> module. Due to reverse RMRO order used, children
classes can override what's provided by parents or roles consumed. For example:

    class MyParent is Vikna::Object {
        submethod profile-default {
            foo => 42,
        }
    }
    class MyChild is MyParent {
        submethod profile-default {
            foo => "is the answer!",
        }
    }

In this case the final default profile will be:

    { foo => "is the answer!", }

Things work similarly for C<profile-checkin>.

=head2 C<submethod profile-default>

Returns just an empty hash as a seed for children profiles.

Must not be invoked by a user.

=head2 C<submethod profile-checkin(%profile, %constructor, %default, %config)>

Merges profiles C<%default>, C<%config>, C<%constructor> using C<Hash::Merge> in the order given into C<%profile>. This
way we get the first iteration of the final profile hash as it will be used to instantiate a new object. Note that the
merging order actually defines priorities of the profile sources making the constructor arguments the most important of
all.

All children C<profile-checkin> submethods are invoked with the same parameters. It makes the initial state available
to any child. It allows to override any changes done to C<%profile> by a parent submethod even if they wipe out initial
keys or change their values.

Must not be invoked by a user.

=head2 C<name()>

Returns object name. The standard name is formed of object's class name and it's C<$.id> attribute. But can be overriden
with corresponding constructor parameter.

=head2 C<multi method throw(X::Base:U \exception, *%args)>
=head2 C<multi method throw(X::Base:D $exception)>

Throws an exception. Because all Vikna exceptions are recording the object which thrown them, this method is a convenient
shortcut which passes the required parameter to the exception constructor:

    class X::MyException is X::Base { ... }
    ...
    $obj.throw: X::MyException, :details($info);

The second candidate of the method simply rethrows a pre-created exception object.

=head2 C<multi method fail(X::Base:U \exception, *%args)>
=head2 C<multi method fail(X::Base:D $exception)>

Similar to C<throw> above, but invokes C<fail> with the exception object.

=head2 C<trace(|)>

This method is a shortcur to L<C<Vikna::App>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/App.md> method C<trace>. It passes the invoking object alongside with the
arguments capture.

=head2 C<flow(&code, Str :$name, :$sync = False, :$branch = False)>

Creates a new code flow (see L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>).
A flow can be created as:

=item asynchronous, in it's own thread
=item synchronous, invoked in the current thread
=item a branch in which case a potentially threading block is considered as a branch of the current flow

The last case is potentially useful for cases when event if a new thread is created, the code in it is a logical
continuation of the current flow.

The method returns a promise which would be kept with flow's return value.

I<NOTE> that flows are tracked using C<$*VIKNA-FLOW> dynamic variable. Sometimes dynamics are not preserved in
lexically enclosed blocks. In such cases it is possible to re-use a flow by temporarily storing it in a lexical and
re-assiging later to C<$*VIKNA-FLOW>.

=head2 C<allocate-flow>, C<free-flow>

Internal implementation details.

=head2 C<panic(Exception:D $cause)>

Standard method to bail out in case of problems. Basically, overriden by higher-order classes.

=head2 C<Str>

Shortcuts to C<name> method.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

unit class Vikna::Object;

use Vikna::X;
use AttrX::Mooish;
use Hash::Merge;

my class CodeFlow {
    has UInt $.id;
    has Str:D $.name is rw = "*anon*";
    has Promise $.promise is rw;
    has PseudoStash $!ctx is built(True);
    has Vikna::Object:D $.owner is required;

    method EXISTS-KEY(Str:D $var) {
        DYNAMIC::{$var}:exists || ($!ctx andthen (.{$var}:exists || (.<$*VIKNA-FLOW>:exists && .<$*VIKNA-FLOW>.EXISTS-KEY($var))))
    }
    method AT-KEY(Str:D $var --> Mu) is raw {
        fail X::Dynamic::NotFound.new(:name($var)) unless self.EXISTS-KEY($var);
        if DYNAMIC::{$var}:exists {
            DYNAMIC::{$var}
        }
        elsif $!ctx.{$var}:exists {
            $!ctx.{$var}
        }
        else {
            $!ctx.<$*VIKNA-FLOW>.AT-KEY($var)
        }
    }
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
    self.WALK(:name<profile-default>, :!methods, :roles).reverse.().map({ merge-hash %default, %$_, :no-append-array });
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
    merge-hash(%profile, %default, :no-append-array);
    merge-hash(%profile, %config, :no-append-array);
    merge-hash(%profile, %constructor, :no-append-array);
}

method build-id {
    use nqp;
    nqp::objectid(self)
}

method !build-name {
    self.^name ~ "<" ~ $.id ~ ">"
}

multi method name(::?CLASS:D:) {
    $!name
}
multi method name(::?CLASS:U:) {
    self.^name
}

multi method throw(X::Base:D $ex) {
    $ex.rethrow
}

multi method throw(X::Base:U \exception, *%args) {
    exception.new(:obj(self), |%args).throw
}

multi method fail(X::Base:D $ex) {
    fail $ex
}

multi method fail(X::Base:U \exception, *%args) {
    fail exception.new(:obj(self), |%args)
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

my @flows is default(0);
my Lock:D $flow-lock .= new;
method allocate-flow(Str :$name? is copy, :$in-context) {
    $flow-lock.lock;
    LEAVE $flow-lock.unlock;
    my $id;
    for ^Inf {
        unless @flows[$_] {
            $id = $_;
            last
        }
    }
    $name //= "<anon" ~ $id ~ ">";
    @flows[$id] =
        CodeFlow.new:
            :$id, :$name, :owner(self),
            |(:ctx(CLIENT::DYNAMIC::) if $in-context);
}

method free-flow(CodeFlow:D $flow) {
    $flow-lock.protect: {
        @flows[$flow.id]:delete
    }
}

method flow(&code, Str :$name?, :$sync = False, :$branch = False, :$in-context = False, Capture:D :$args = \()) {
    my $cur-flow = DYNAMIC::<$*VIKNA-FLOW>:exists ?? $*VIKNA-FLOW !! Nil;
    my $flow = $branch && $cur-flow
            ?? self.allocate-flow(:name($cur-flow.name), :in-context)
            !! self.allocate-flow(:$name, :$in-context);

    my sub flow-start {
        my $*VIKNA-FLOW = $flow;
        LEAVE self.free-flow($flow);
        &code(|$args);
    }

    if $sync {
        Promise.kept(flow-start);
    }
    else {
        ($flow.promise = (Promise.start(&flow-start))).then: {
            my $*VIKNA-FLOW = $flow;
            if .status ~~ Broken {
                self.trace: "FLOW BROKEN: " ~ .cause, ~.cause.backtrace, :error;
                note "===FLOW `{ $flow.name }` on { self } PANIC!=== ", .cause.message, "\n", .cause.backtrace.Str;
                self.panic(.cause);
                .cause.rethrow;
            }
            .result
        };
    }
}

method panic(Exception:D $cause) {
    note "===PANIC!=== On object ", self.?name // self.WHICH, "\n", $cause.message, "\n", ~$cause.backtrace;
    exit 1;
}

multi method Str {
    self.name
}
