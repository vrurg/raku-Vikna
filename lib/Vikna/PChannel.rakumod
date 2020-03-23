use v6.e.PREVIEW;

# Prioritized channel.
unit class Vikna::PChannel;

use nqp;
use Vikna::X;
use Vikna::PChannel::NoData;

my class PQueue is repr('ConcBlockingQueue') { }

# Atom of 'data available' semaphore. This works the following way: if a receive operation encounters 'no packets'
# situation, it raises the awaited flag and starts awaiting for the promise. If send sees the flag to be raised it
# replaces the atom ($!on-data) with a new one and then keeps the promise. At this moment all receive operations pending
# will awake and race for any new packets available.
my class OnDataNode {
    has Promise:D $.promise .= new;
    has $.awaited is rw = False;
}

# The channel has been closed. Yet, some data might still be awailable for fetching!
has Bool:D $.closed = False;
has Promise:D $.closed_promise .= new;
# The channel is closed and no more data left in it.
has Bool:D $.drained = False;
has Promise:D $.drained_promise .= new;

# Number of elements available in all priority queues; i.e. in the channel itself. Has limited meaning in concurrent
# environment.
has atomicint $.elems = 0;

# The semaphore for awaiting receive operations.
has OnDataNode:D $!on-data .= new;
# Total number of priority queues allocated
has atomicint $.prio-count = 0;
# Number of the highest priority queue where it's very likely to find some data. This attribute is always updated when
# send receives a packet. A poll might set it to lower value if it finds an empty priority queue.
has $!max-prio-updated = -1;
# ID of the last update of $!max-prio-updated. Allows receive operations not to overwrite what's been set by send unless
# ok to do so.
has $!MPU-ID = 0;
# List of priority queues. For performance matters, it must be a nqp::list()
has $!pq-list;
has Lock:D $!prio-lock .= new;

submethod TWEAK(:$priorities = 1, |) {
    die "Bad number of priorities in {self.^name} constructor: must be 1 or more but got {$priorities}" unless $priorities > 0;
    $!pq-list := nqp::list();
    self!pqueue($priorities - 1); # Pre-create priorities.
}

# Must only be called if no priority queue is found for a specified priority. It pre-creates necessary entries in
# $!pq-list.
method !pqueue(Int:D $prio) is raw {
    $!prio-lock.protect: {
        until $prio < $!prio-count {
            my $new-count = $!prio-count * 2;
            nqp::while(
                nqp::isle_i($!prio-count, $new-count),
                nqp::stmts(
                    nqp::push($!pq-list, PQueue.new),
                    nqp::atomicinc_i($!prio-count)
                )
            );
        }
    }
    nqp::atpos($!pq-list, $prio)
}

method send(Mu \packet, UInt:D $prio = 0) {
    if $!closed {
        X::PChannel::OpOnClosed.new(:op<send>).throw
    }
    my $pq := nqp::atpos($!pq-list, $prio);
    nqp::if(
        nqp::unless(nqp::isge_i($prio, $!prio-count), nqp::isnull($pq)),
        ($pq := self!pqueue($prio))
    );
    nqp::push($pq, packet);
    # $pq.enqueue: packet;
    # Sumulate a lock. I.e. we'll try updating $!max-prio-updated only when allowed to update the associated $!MPU-ID.
    cas $!MPU-ID, {
        nqp::if(
            nqp::isge_i($prio, $!max-prio-updated),
            ($!max-prio-updated = $prio)
        );
        # nqp::add_i allows $!MPU_ID not to turn into a bigint. Instead it would rotate over if ever reaches 2^64-1.
        nqp::add_i($_, 1)
    };
    nqp::atomicinc_i($!elems);
    if (my $old = $!on-data).awaited && !$!closed {
        # Signal of new data if can. If $!on-data cannot be updated it means a cocurrent send has done the job already
        # and we must not care.
        if cas($!on-data, $old, OnDataNode.new) === $old {
            $old.promise.keep(True);
        }
    }
}

method close {
    if cas($!closed, False, True) {
        # Two concurrent closes? Not good.
        X::PChannel::OpOnClosed.new(:op<close>).throw;
    }
    $!closed_promise.keep(True);
    $!on-data.promise.keep(True);
}

method !drain {
    unless cas($!drained, False, True) {
        $!drained_promise.keep(True);
    }
}

method failed {
    $!closed_promise.status ~~ Broken
}

# XXX Would need better handling for when promise is not broken
method cause {
    $!closed_promise.cause
}

method fail($cause) {
    if cas($!closed, False, True) {
        # Two concurrent closes? Not good.
        X::PChannel::OpOnClosed.new(:op<close>).throw;
    }
    $!closed_promise.break($cause);
    $!on-data.promise.keep(True);
}

method poll is raw {
    my $packet;
    my $found := False;
    my $fprio = -1;
    if $!elems {
        my $prio;
        my $my-id;
        # A lock-like operation to ensure the $!max-prio-updated and the $!MPU-ID are associated.
        cas $!MPU-ID, {
            $prio = $!max-prio-updated + 1;
            $my-id = $_
        };
        # We iterate starting with the latest $!max-prio-updated available to us. Then we try polling the first queue
        # which has non-empty $!elems. This is not guaranteed that it will still have any data for us when we eventually
        # call .poll on it but this way we surely not wasting time on empty ones.
        nqp::while(
            nqp::if(nqp::not_i($found), (--$prio >= 0)),
            nqp::unless(
                nqp::isnull($packet := nqp::queuepoll(nqp::atpos($!pq-list, $prio))),
                nqp::stmts(
                    ($found := True),
                    ($fprio = $prio)
                )
            )
        );
        # Now we can update the $!max-prio-update if a packet was found in a queue with lower priority and the attribute
        # hasn't been updated by a send since we got it. This ensures that poll has less rights on updating the
        # attribute and this we won't miss a packet with higher prio when it arrives.
        cas $!MPU-ID, {
            $!max-prio-updated = $prio if $_ == $my-id && $prio < $!max-prio-updated;
            $_
        }
    }
    if $found {
        nqp::atomicdec_i($!elems);
        $packet
    }
    else {
        # If no data found and the channel has been closed then it's time to report draining. No more packets will
        # appear here.
        self!drain if $!closed;
        Nil but NoData
    }
}

method receive is raw {
    loop {
        my $packet := $.poll;
        if $!drained {
            return Failure.new( X::PChannel::OpOnClosed.new(:op<receive>) );
        }
        if $packet ~~ NoData {
            # Given ensures that we operate on the same atom even if it gets updated by a send in a concurrent thread.
            given $!on-data {
                .awaited = True;
                await Promise.anyof( .promise, $!drained_promise );
            }
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
            if $v ~~ Failure && $v.exception ~~ X::PChannel::OpOnClosed {
                $v.so;
                done;
            }
            else {
                emit $v;
            }
        }
    }
}
