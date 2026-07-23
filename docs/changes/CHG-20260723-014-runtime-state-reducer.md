# CHG-20260723-014 — Extract the reducer-owned runtime session

- Status: complete
- Change-Type: optimization
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-004
- BC: BC-007
- ADR: ADR-0014
- Design: SYSTEM-ARCHITECTURE
- TR: TR-RUNTIME-20260723-002, TR-GOVERNANCE-20260723-003

## Purpose

Remove the AppKit window controller's duplicate behavior, animation, physics
and package-session state so the core runtime has one deterministic state and
can be tested independently.

## Before: badcase and risk

BC-007 reproduces state ownership split across `BehaviorEngine` and
`PetWindowController`. The risk is incomplete package resets, event/pose drift,
and regressions that require an interactive window to reproduce.

## Design impact

Implements ADR-0014 and the single-state boundary in
`docs/design/SYSTEM-ARCHITECTURE.md`. The adapter still owns AppKit pointer,
timer, scheduler and window-placement transients; these are effects/input
translation, not authoritative behavior state.

## Changes

- Add `PetRuntimeState` with contract, generation, reducer, animation and
  physics step APIs.
- Keep `PetSessionCoreState` as a compatibility typealias.
- Make the window controller delegate core state mutation and reads to the
  runtime value.
- Add focused reducer, animation and physics regression tests.

## Compatibility

Animation selection, physics equations, package contract resolution and
session reset semantics are unchanged. Existing callers of
`PetSessionCoreState` continue to compile through the typealias. The controller
still receives the same `PetEvent` values and renders the same frame IDs.

## Test evidence

TR-RUNTIME-20260723-002 is the final content-matched passing verification.
TR-RUNTIME-20260723-001 remains as the earlier pass before the compiler-
enforced mutation boundary was tightened. The staged-gate failure caused by
the missing evidence reference is preserved in TR-GOVERNANCE-20260723-003.

## Rollback

Revert this change and restore the controller's three stored core values. Keep
ADR-0014 and its evidence as historical records; do not rewrite them.

## Revision log

- 2026-07-23: created before implementation on `codex/runtime-controller-split`.
