use v6;
# use Test::Async;
use Test::Async;
use Vikna::Tracer;
use Vikna::Object;

plan 8;

my $obj = Vikna::Object.new;

# Tracer can only run inside a flow.
$obj.flow: :sync, :name('TEST TRACER'), {
    my $test-db = $*SPEC.catfile($*SPEC.tmpdir, "Test.sqlite");
    sub wipe-db {
        if $test-db.IO.e {
            $test-db.IO.unlink;
        }
    }
    wipe-db;

    # diag "TDB: " ~ $test-db;

    my $tr;
    lives-ok {
        $tr = $obj.create: Vikna::Tracer, :db-name($test-db), :session-name('Test 1');
    }, "tracer created";

    for ^10 {
        $tr.record($tr, "test 1 line " ~ $_);
    }

    is $tr.session-id, 1, "first session id";

    $tr.session-name = "Test 2";

    for ^10 {
        $tr.record($tr, "test 2 line " ~ $_);
    }

    is $tr.session-id, 2, "second session id";

    is $tr.sessions.elems, 2, "have two sessions";
    is $tr.sessions[0].name, "Test 1", "first session name";
    is $tr.sessions[1].name, "Test 2", "second session name";

    for $tr.sessions -> $sess {
        # diag "SESS: " ~ $sess.id;
        subtest "Session " ~ $sess.id => {
            plan 10;
            my $prev-time = DateTime.new: 0;
            my $id = 0;
            for $sess.records -> $rec {
                subtest "Record " ~ $id => {
                    plan 3;
                    # diag join ", ", $rec.session-id ~ "#" ~ $rec.id, ~$rec.time, " ", $rec.object-id, " ", $rec.message;
                    is $rec.message, "test " ~ $sess.id ~ " line " ~ $id, "$id. record message";
                    is $rec.id, ++$id, "record id";
                    ok $rec.time > $prev-time, "record time is sequential";
                    $prev-time = $rec.time;
                }
            }

        }
    }

    wipe-db;
}

done-testing;
