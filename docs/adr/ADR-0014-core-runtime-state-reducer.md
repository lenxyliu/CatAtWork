# ADR-0014 — Make `PetRuntimeState` the single reducer-owned session

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-014
- ISSUE: ISSUE-004

## Context

`PetWindowController` had its own `BehaviorEngine`, `AnimationPlayer`,
`PetPhysics`, package contract and session-generation fields. AppKit event
handlers, clocks and rendering code could therefore observe and mutate a
second runtime state machine, while the platform-neutral core could not be
tested as one session boundary.

## Decision

Introduce `PetRuntimeState` in `CatAtWorkCore` as the authoritative package
session. It owns the validated contract, behavior engine, animation player,
physics and generation. Its reducer and animation/physics step methods are the
only core mutation boundary. `PetWindowController` keeps only AppKit adapter
state (window, pointer, timers, scheduling and presentation transients),
translates events to the reducer, and applies the resulting effects.

`PetSessionCoreState` remains a source-compatible typealias during migration;
new code and tests use `PetRuntimeState`.

## Consequences

Session replacement atomically resets queue, pose, animation time, velocity
and generation. Core tests can exercise event, animation and physics traces
without AppKit. Window-specific policy such as pointer-interest timers and
screen placement remains adapter-owned because it depends on platform clocks
and window geometry; it must not duplicate core behavior decisions.

## Rejected alternatives

- Moving every pointer/autonomy timer into Core now would couple the reducer to
  AppKit time and geometry before an explicit effect model exists.
- Keeping three controller-owned core values would preserve the reset and test
  drift that this decision removes.
