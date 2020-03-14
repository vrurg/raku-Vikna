use v6.e.PREVIEW;

# Prioritized channel.
unit class Vikna::PChannel;

use Vikna::X;
use Vikna::PChannel::NoData;
use Concurrent::Queue;

has Promise:D $.closed_promise .= new;
has Promise:D $.drained_promise .= new;

# This lock unlocks when there is data
has Promise:D $!on-data .= new;
has Concurrent::Queue:D @!channels;
has Lock:D $!chan-lock .= new;

method !maybe-got-data {
    $!chan-lock.protect: {
        $!on-data.keep(True);
        $!on-data .= new;
    }
}

method send(Mu \packet, UInt:D() $prio = 0) {
    CATCH {
        when X::Lock::Async::NotLocked {
            .resume
        }
        default {
            .rethrow
        }
    }
    X::PChannel::SendOnClosed.new.throw if $.closed;
    $!chan-lock.protect: {
        while +@!channels < ($prio + 1) {
            @!channels.push: Concurrent::Queue.new;
        }
    }
    @!channels[$prio].enqueue: packet;
    self!maybe-got-data;
}

method close {
    $!closed_promise.keep(True);
    self!maybe-got-data;
}

method closed {
    $!closed_promise.status !~~ Planned
}

method drained {
    $!drained_promise.status !~~ Planned
}

method failed {
    $!closed_promise.status ~~ Broken
}

# XXX Would need better handling for when promise is not broken
method cause {
    $!closed_promise.cause
}

method fail($cause) {
    $!closed_promise.break($cause);
}

method poll(--> Mu) is raw {
    my $packet;
    my $found;
    for @!channels.eager.reverse -> $queue {
        unless ($packet = $queue.dequeue) ~~ Failure {
            $found = True;
            last;
        }
        $packet.so;
    }
    return $packet if $found;
    $!chan-lock.protect: {
        if $.closed {
            $!drained_promise.keep(True) if $!drained_promise.status ~~ Planned;
            Failure.new( X::PChannel::ReceiveOnClosed.new );
        }
        else {
            Nil but NoData;
        }
    }
}

method receive is raw {
    loop {
        my $packet = $.poll;
        if $packet ~~ NoData {
            $packet.so; # Acknowledge Failure
            await Promise.anyof( $!on-data, $!drained_promise );
        }
        else {
            return $packet;
        }
    }
}

method Supply {
    supply {
        loop {
            my $v = self.receive;
            if $v ~~ Failure && $v.exception ~~ X::PChannel::ReceiveOnClosed {
                $v.so;
                done;
            }
            else {
                emit $v;
            }
        }
    }
}
