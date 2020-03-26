use v6.e.PREVIEW;

unit class Vikna::Tracer;

use AttrX::Mooish;
use DB::SQLite;

class Records {...}

class Session {
    has UInt:D          $.id        is required;
    has Str:D           $.name      is required;
    has DateTime:D      $.started   is required;
    has Vikna::Tracer:D $.tracer    is required;

    method BUILDALL(\autovivs, %attrinit) {
        if %attrinit<started> && %attrinit<started> ~~ Numeric {
            %attrinit<started> = DateTime.new: %attrinit<started>
        }
        nextsame
    }

    submethod TWEAK(DateTime:D() :$!started, |) { }

    has Records $.records is mooish(:lazy);

    method build-records {
        Records.new: session => self
    }
}

class Record {
    has UInt:D      $.id           is required;
    has DateTime:D  $.time         is required;
    has Int:D       $.flow-id      is required is mooish(:alias<flow_id>);
    has Str:D       $.flow-name    is required is mooish(:alias<flow_name>);
    has Str:D       $.object-id    is required is mooish(:alias<object_id>);
    has Str:D       $.message      is required;
    has Str:D       $.class        is required; # Record class like shutdown, etc.
    has UInt:D      $.session-id   is required is mooish(:alias<session_id>);

    method BUILDALL(\autovivs, %attrinit) {
        if %attrinit<time> && %attrinit<time> ~~ Numeric {
            %attrinit<time> = DateTime.new: %attrinit<time>
        }
        nextsame;
    }
}

# Provide support for tracer script only for now. Basic stuff.
class Records {
    has Session:D $.session is required;

    method elems {
        $!session.tracer.db.query('SELECT count(id) FROM record WHERE session_id == ?', $!session.id).value
    }

    method flows {
        $!session.tracer.db.query('SELECT DISTINCT flow_id FROM record').arrays.map: *[0]
    }

    method iterator {
        $!session
            .tracer.db
            .query('SELECT * FROM record WHERE session_id = ? ORDER BY time ASC', $!session.id)
            .hashes.map( { Record.new: |$_ } ).iterator
    }
}

has Str:D $.db-name = "Vikna.sqlite";
has Str $.session-name is rw is mooish(:lazy, :predicate, :trigger);
has $.session-id is mooish(:lazy, :predicate, :clearer);
has Channel $!msg-queue is mooish(:lazy, :clearer);
has Bool $.to-err = False;
has Bool $!shutdown;
has atomicint $!record-id = 0;
has atomicint $!submitted = 0;
has DB::SQLite $.sqlite is mooish(:lazy);
has DB::SQLite::Connection $.db is mooish(:lazy);
has $!rec-sth is mooish(:lazy);

method build-sqlite {
    my $sqlite = DB::SQLite.new(filename => $!db-name);
    $sqlite.execute(q:to/SSQL/);
        CREATE TABLE IF NOT EXISTS session (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            started REAL NOT NULL
        )
        SSQL
    $sqlite.execute(q:to/RSQL/);
        CREATE TABLE IF NOT EXISTS record (
            id INTEGER NOT NULL,
            time REAL NOT NULL,
            flow_id INTEGER NOT NULL,
            flow_name TEXT NOT NULL,
            object_id TEXT NOT NULL,
            message TEXT NOT NULL,
            class TEXT NOT NULL,
            session_id INTEGER NOT NULL
        )
        RSQL
    $sqlite
}

method build-db {
    my $db = $!sqlite.db;
    $db.execute('PRAGMA synchronous = OFF');
    $db.execute('PRAGMA journal_mode = MEMORY');
    $db.execute('PRAGMA temp_store = MEMORY');
    $db.execute('PRAGMA cache_size = 1000000');
    $db
}

method !build-rec-sth {
    $!db.prepare(q:to/INS_SQL/);
        INSERT INTO record (
            id, time, flow_id, flow_name, object_id, message, class, session_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        INS_SQL
}

method !build-msg-queue {
    my Channel $queue .= new;
    my $count = 0;
    my $reported;
    start {
        while $queue.receive -> &block {
            &block();
            ++$count;
            if $!shutdown {
                unless $reported {
                    note "\nDUMPING REMAINING TRACING RECORDS. ALREADY PROCESSED: ", $count;
                    $reported = $count;
                }
                $*ERR.printf: "%8d/%8d of %8d %3.2f%%\r", ($count - $reported), $count, $!submitted, ($count * 100/ $!submitted)
                    if ($count % 100) == 0;
            }
        }
        CATCH {
            # Just ignore
            note "\nTotally processed: ", $count;
            when X::Channel::ReceiveOnClosed {
                note "Finished by channel close";
            }
            default {
                note "TRACER FAILURE: ", .message ~ .backtrace;
                exit 1;
            }
        }
    }
    $queue;
}

method build-session-name {
    $*VIKNA-APP.^name
}

method trigger-session-name( $name, :$builder?, :$old-value?, *%p ) {
    if !$builder && $old-value.defined && ($name ne $old-value) {
        $.clear-session-id if $.has-session-id;
    }
}

method build-session-id {
    $!record-id ⚛= 0;
    $!db.query('INSERT INTO session (name, started) VALUES (?, ?)', $!session-name, now.Rat);
    $!db.query('SELECT last_insert_rowid()').value
}

method cue(&code) {
    my $p = Promise.new;
    CATCH {
        when X::Channel::SendOnClosed {
            $p.keep(False);
            .resume;
        }
        default { .rethrow }
    }
    $!msg-queue.send: {
        $p.keep(&code());
        CATCH {
            default {
                $p.break($_)
            }
        }
    }
    $p
}

method sessions {
    await $.cue: {
        $!db.query('SELECT * FROM session').hashes.eager.map: { Session.new(:tracer(self), |$_) };
    }
}

method session(Int:D $id) {
    await $.cue: {
        Session.new: :tracer(self), |$!db.query('SELECT * FROM session WHERE id == ?', $id).hash
    }
}

multi method record(
        Str:D :$object-id,
        Str:D :$message,
        Any:D :$flow = $*VIKNA-FLOW,
        Rat:D :$time = now.Rat,
        Str:D :$class = 'default'
    )
{
    note $message if $!to-err;
    ++⚛$!submitted;
    # Pre-store session id to prevent the record be written to another session if id changes dynamically.
    my $session-id = $!session-id;
    $.cue: {
        CATCH {
            note $_, ~.backtrace;
            exit 1;
        }
        # TODO: Replace with something more readable, perhaps.
        $!rec-sth.execute(
            ++⚛$!record-id,
            $time,
            $flow.id,
            $flow.name,
            $object-id,
            $message,
            $class,
            $session-id
        )
    }
}

multi method record($object, Str:D $message, *%c) {
    $.record: object-id => ~$object.WHICH, :$message, |%c
}

method shutdown {
    # Flush all queued events.
    my $last = $.cue: { True };
    $!shutdown = True;
    $!msg-queue.close;
    await $last;
    $!db.finish;
    $!sqlite.finish;
}

method templates {
    %( gather {
        for $?DISTRIBUTION.meta<resources>.grep( *.index('tracer/') == 0 ) -> $tmpl {
            my $format = S/\. \w+ $// with $tmpl.substr(7);
            take $format => %?RESOURCES{$tmpl};
        }
    } )
}
