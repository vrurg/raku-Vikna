use v6.e.PREVIEW;
use Test::Async;
use Vikna::Object;
use Vikna::Utils;

plan 3, :parallel;

subtest "In context" => -> \suite {
    plan 6;
    my $obj = Vikna::Object.new;
    my $*VIKNA-VAR = "is here";

    await $obj.flow: {
        suite.isa-ok: $*VIKNA-FLOW<$*VIKNA-VAR>, Failure, "plain flow doesn't see outer dynamics";
        suite.isa-ok: $*VIKNA-FLOW<$*VIKNA-VAR>.exception, X::Dynamic::NotFound, "returned failure contains X::Dynamic::NotFound";
    };

    await $obj.flow: :name('Test Flow'), :in-context, {
        my $*VIKNA-VAR2 = "in flow";
        suite.is: $*VIKNA-FLOW<$*VIKNA-VAR>, "is here", "in context flow sees dynamics";
        $obj.flow: {
            suite.fails-like:
                { $*VIKNA-FLOW<$*VIKNA-VAR> },
                X::Dynamic::NotFound,
                "nested plain flow doesn't see outer dynamics",
                :name<$*VIKNA-VAR>;
        }

        my $t = Thread.start: flow-branch {
            suite.is: $*VIKNA-FLOW<$*VIKNA-VAR>, "is here", "flow-branch preserves access to the dynamic context";
            suite.is: $*VIKNA-FLOW<$*VIKNA-VAR2>, "in flow", "flow-branch can see originating flow context";
        }
        $t.finish;
    }
}

subtest "Branching" => -> \suite {
    plan 5;
    my $obj = Vikna::Object.new;

    await $obj.flow: :name("main"), {
        my $vf = $*VIKNA-FLOW;
        my $t = Thread.start: {
            suite.fails-like:
                { $*VIKNA-FLOW },
                X::Dynamic::NotFound,
                q‘control: $*VIKNA-FLOW is not normally accessible in an async block’,
                :name<$*VIKNA-FLOW>;
        };
        $t.finish;
        $t = Thread.start: flow-branch {
            suite.ok: ?$*VIKNA-FLOW, q‘flow-branch preserves $*VIKNA-FLOW’;
            suite.cmp-ok: $*VIKNA-FLOW.name, 'eq', $vf.name, "flow-branch preserves flow name";
        };
        $t.finish;

        my @p;
        @p.push: $obj.flow: :name('non-branch'), {
            suite.ok: $*VIKNA-FLOW !=== $vf, q‘non-branching flow has own $*VIKNA-FLOW’;
        }
        @p.push: $obj.flow: :name('branch'), :branch, {
            suite.cmp-ok: $*VIKNA-FLOW.name, 'eq', $vf.name, q‘flow branch preserves the name’;
        }
        await @p;
    }
}

subtest "Return Value" => {
    plan 2;
    my $obj = Vikna::Object.new;
    my $rc = await $obj.flow: :name('async'), { 42 };
    is $rc, 42, "async flow return value";

    $rc = await $obj.flow: :name('sync'), :sync, { π };
    is $rc, π, "sync flow return value";
}