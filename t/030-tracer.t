use v6;
use Test;
use Vikna::Tracer;
use Vikna::Tracer::Session;
use Vikna::Tracer::Record;

my $test-db = "Test.sqlite";
if $test-db.IO.e {
    $test-db.IO.unlink;
}

note "Start 1";
my $tr = Vikna::Tracer.new: :db-name<Test.sqlite>, :session-name('Test 1');

note "Records 1";
for ^10 {
    $tr.record($tr, "test 1 line " ~ $_);
}

note "Start 2";
$tr.session-name = "Test 2";

note "Records 2";
for ^10 {
    $tr.record($tr, "test 2 line " ~ $_);
}

say $tr.sessions.map({.name ~ "#" ~ .id});
for $tr.sessions[0].records -> $rec {
    note ~DateTime.new($rec.time), " ", $rec.message;
}

$test-db.IO.unlink;
