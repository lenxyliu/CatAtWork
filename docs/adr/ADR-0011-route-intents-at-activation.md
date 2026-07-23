# ADR-0011 — Route queued intents at activation

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-010
- ISSUE: ISSUE-001

## Context

BehaviorEngine expanded pose bridges when an intent was submitted.
ActionCoordinator then prioritized each bridge and target as unrelated queue
entries. A later higher-priority intent could change the actual pose before an
older target started, leaving that target without a valid bridge.

## Decision

Store only original intents in the priority/FIFO queue. When an intent wins
selection, build an atomic plan from the actual committed pose: authored
bridges followed by the target. Finish the entire plan before returning to
priority arbitration.

Both timed expiry and explicit animation completion commit the finished
animation's end pose before selecting and planning the next intent. Target
durations start only when the target step becomes active.

## Consequences

Priority still chooses between waiting intents and equal priority remains
FIFO. A higher-priority intent arriving during a selected bridge waits until
that bridge's target completes; this is intentional atomicity. Forced
physical actions continue to clear queued and atomic continuations.
