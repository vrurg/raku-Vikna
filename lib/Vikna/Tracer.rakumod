use v6.e.PREVIEW;

unit class Vikna::Tracer;
use Red:api<2>;

use AttrX::Mooish;
use Vikna::Tracer::Session;
use Vikna::Tracer::Record;

has Str:D $.db-name = "Vikna.sqlite";
has Str $.session-name is rw is mooish(:lazy, :predicate, :filter);
has Vikna::Tracer::Session $.session is mooish(:lazy, :predicate, :clearer);
has Channel $!msg-queue is mooish(:lazy, :clearer);
has Bool $.to-err = False;

submethod TWEAK {
    red-defaults default => (database "SQLite", database => $!db-name);
}

method !build-msg-queue {
    my Channel $queue .= new;
    start react {
        whenever $queue -> &block {
            &block();
        }
    }
    $queue;
}

method build-session-name {
    $*VIKNA-APP.^name
}

method filter-session-name( $name, *%p ) {
    if %p<old-value>:exists && ($name ne %p<old-value>) {
        $.clear-session;
    }
    $name;
}

method build-session {
    await $.cue: {
        Vikna::Tracer::Session.^create-table: :unless-exists;
        Vikna::Tracer::Record.^create-table: :unless-exists;

        Vikna::Tracer::Session.^create: :started(now.Rat), :name($!session-name);
    }
}

method cue(&code) {
    my $p = Promise.new;
    $!msg-queue.send: {
        red-do {
            $p.keep(&code());
        }
        CATCH {
            default {
                $p.break(Failure.new($_))
            }
        }
    }
    $p
}

method sessions {
    await $.cue: {
        Vikna::Tracer::Session.^all
    }
}

method session(Int:D $id) {
    await $.cue: {
        Vikna::Tracer::Session.^all.grep( *.id == $id ).head
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
    my $session-id = $!session.id;
    note $message if $!to-err;
    await $.cue: {
        Vikna::Tracer::Record.^create:
            session-id => $session-id,
            :flow($flow.id),
            :flow-name($flow.name),
            :$time, :$object-id, :$message, :$class;
    }
}

multi method record($object, Str:D $message, *%c) {
    $.record: object-id => ~$object.WHICH, :$message, |%c
}

method shutdown {
    # Flush all queued events.
    await $.cue: { True };
    $!msg-queue.close;
}

method templates {
    %( gather {
        for $?DISTRIBUTION.meta<resources>.grep( *.index('tracer/') == 0 ) -> $tmpl {
            my $format = S/\. \w+ $// with $tmpl.substr(7);
            take $format => %?RESOURCES{$tmpl};
        }
    } )
}
