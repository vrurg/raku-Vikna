NAME
====

`Vikna::Object` - the base class of most of `Vikna` classes

DESCRIPTION
===========



This class implements the basic functionality required by many of `Vikna` classes.

ATTRIBUTES
==========



`$.app`
-------

The application this object has been created under. For example, a typical access to the desktop object is done via:

    $.app.desktop

`Int $.id`
----------

Integer unique object id. Implementation dependant and thus one can't rely upon its current implementation. Only makes sense in object comparison, caching, etc.

Lazy, built by `build-id` method. See [`AttrX::Mooish`](https://modules.raku.org/dist/AttrX::Mooish:cpan:VRURG).

METHODS
=======



`new(*%c)`
----------

Acts more as a wrapper to the standard method new. This is where profiles are merged and the result is then used to call the standard `new` method.

`create(Mu \type, |c)`
----------------------

This method has to be used by any `Vikna::Object` descendant to create a new Vikna object. The method guarantees that the application object will be propagated to all newly created instances.

`make-object-profile(%c)`
-------------------------

This method implements the magic of object profiles. But before getting into details, I recommend to read about RMRO in [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md) unless already done so.

The argument is the profile as it is supplied to the constructor.

In details, the method:

  * requests for configuration profile from the application object if known;

  * walks over `profile-default` submethods in reverse RMRO order and collects default profiles. Then merges them into a single default profile hash;

  * walks over `profile-checkin` submethods in reverse RMRO order and invokes them with the destination profile hash object, constructor-supplied profile hash, the merged default profile, and config

The hashes are merged using deep merge as implemented by `Hash::Merge` module. Due to reverse RMRO order used, children classes can override what's provided by parents or roles consumed. For example:

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

Things work similarly for `profile-checkin`.

`submethod profile-default`
---------------------------

Returns just an empty hash as a seed for children profiles.

Must not be invoked by a user.

`submethod profile-checkin(%profile, %constructor, %default, %config)`
----------------------------------------------------------------------

Merges profiles `%default`, `%config`, `%constructor` using `Hash::Merge` in the order given into `%profile`. This way we get the first iteration of the final profile hash as it will be used to instantiate a new object. Note that the merging order actually defines priorities of the profile sources making the constructor arguments the most important of all.

All children `profile-checkin` submethods are invoked with the same parameters. It makes the initial state available to any child. It allows to override any changes done to `%profile` by a parent submethod even if they wipe out initial keys or change their values.

Must not be invoked by a user.

`name()`
--------

Returns object name. The standard name is formed of object's class name and it's `$.id` attribute. But can be overriden with corresponding constructor parameter.

`multi method throw(X::Base:U \exception, *%args)`
--------------------------------------------------

`multi method throw(X::Base:D $exception)`
------------------------------------------

Throws an exception. Because all Vikna exceptions are recording the object which thrown them, this method is a convenient shortcut which passes the required parameter to the exception constructor:

    class X::MyException is X::Base { ... }
    ...
    $obj.throw: X::MyException, :details($info);

The second candidate of the method simply rethrows a pre-created exception object.

`multi method fail(X::Base:U \exception, *%args)`
-------------------------------------------------

`multi method fail(X::Base:D $exception)`
-----------------------------------------

Similar to `throw` above, but invokes `fail` with the exception object.

`trace(|)`
----------

This method is a shortcur to [`Vikna::App`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/App.md) method `trace`. It passes the invoking object alongside with the arguments capture.

`flow(&code, Str :$name, :$sync = False, :$branch = False, :$in-context = False, Capture:D :$args = \())`
---------------------------------------------------------------------------------------------------------

Creates a new code flow (see [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md)). A flow can be created either as an asynchronous one running in its own thread; or as a synchronous, invoked on the current thread context. The flow will execute `&code` with arguments from `:args` parameter.

It is often the case that when a new thread is spawned it doesn't have access to the dynamic context of the code which spawned the thread. With `:in-context` argument the flow records its caller's context allowing to search for dynamics in it using hash-key syntax:

    if $*VIKNA-FLOW<$*VIKNA-CURRENT-EVENT>:exists {
        $cur-event = $*VIKNA-FLOW<$*VIKNA-CURRENT-EVENT>;
    }

When the flow is created withing a "parent" flow, it would try to chain the search for a dynamic symbol with the "parent".

*NOTE* that the feature is a potential memory hog as it might keep many upstream closures referenced even when nobody else is not using them anymore.

If a new flow is created with `:branch` parameter then it would implicitly take the name of the enclosing flow and will get `:in-context` parameter implicitly.

The method returns a promise which would be kept with flow's return value.

`allocate-flow`, `free-flow`
----------------------------

Internal implementation details.

`panic(Exception:D $cause)`
---------------------------

Standard method to bail out in case of problems. Basically, overriden by higher-order classes.

`Str`
-----

Shortcuts to `name` method.

SEE ALSO
========

[`Vikna`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md), [`Vikna::Manual`](https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md)

AUTHOR
======



Vadim Belman <vrurg@cpan.org>

