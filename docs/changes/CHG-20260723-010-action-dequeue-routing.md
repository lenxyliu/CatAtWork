# CHG-20260723-010 — Route queued actions from the actual pose

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-001
- BC: BC-001
- ADR: ADR-0011
- Design: RUNTIME-STATE-MACHINE
- TR: TR-ACTION-20260723-001

## Purpose

Prevent mixed-priority action queues from separating a pose bridge from its
target or starting a target from a pose invalidated by an earlier winner.

## Before: badcase and risk

While a standing action is active, enqueue a low-priority standing walk and
then a higher-priority seated wave. The old engine precomputes no bridge for
the walk. After the wave returns the pet to seated, the stored walk starts
directly and visibly snaps.

## Design impact

ActionCoordinator distinguishes waiting intents from an atomic active plan.
BehaviorEngine provides the actual-pose planner only when an intent starts.
ADR-0011 records the arbitration boundary.

## Changes

- Queue raw target intents rather than pre-expanded bridge actions.
- Plan authored bridges after priority selection using the current pose.
- Keep selected bridges and target in an atomic continuation.
- Commit pose before expiry/completion selects the next intent.
- Preserve duration-at-activation, force clearing, physical ownership,
  duplicate suppression, bounded queue and FIFO rules.
- Add mixed-priority and atomic-continuation regression tests.

## Compatibility

Public events and animation IDs are unchanged. `queuedActionCount` continues
to include pending steps, including an atomic target waiting behind its
bridge. Normal intents remain non-preemptive once active.

## Test evidence

TR-ACTION-20260723-001 records 26 focused behavior tests, 38 full Swift tests,
build/typecheck/core smoke, default-package validation, governance fixtures
and the final governed-content digest. All required checks passed.

## Rollback

Revert the coordinator planner/continuation change and this branch before
merge. After merge, supersede ADR-0011; do not restore enqueue-time bridge
expansion without a replacement proof for BC-001.

## Revision log

- 2026-07-23: implementation opened after deterministic standing/wave/walk
  reproduction was isolated.
- 2026-07-23: implementation and regression tests completed; ISSUE-001 and
  BC-001 marked fixed against TR-ACTION-20260723-001.
