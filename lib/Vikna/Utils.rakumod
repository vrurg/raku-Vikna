use v6.e.PREVIEW;
unit module Vikna::Utils;

subset Dimension of Int:D is export where * > 0;
subset BasicColor of Any is export where Any:U | Str:D;

constant MBNone   is export = 0;
constant MBLeft   is export = 1;
constant MBMiddle is export = 2;
constant MBRight  is export = 3;

# HoldCollect – preserve all events of a type
# HoldFirst – preserve only first event of a type
# HoldLast – preserve only the last event of a type
enum EvHoldKind is export <HoldCollect HoldFirst HoldLast>;

# Widget children strata
enum ChildStrata is export «:StBack(0) StMain StModal»;
