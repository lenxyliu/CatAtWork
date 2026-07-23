# CHG-20260723-011 — Enforce the pet-package session contract

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-002
- BC: BC-002, BC-003, BC-004
- ADR: ADR-0012
- Design: CATPET-CONTRACT, SYSTEM-ARCHITECTURE
- TR: TR-PACKAGE-20260723-001, TR-PACKAGE-20260723-002

## Purpose

Make manifest capabilities, pose/next metadata, pixel density, hit geometry
and package switching obey one validated runtime contract.

## Before: badcase and risk

Unknown actions silently rendered idle; pose strings and density metadata were
not enforced; `nextAnimation` was ignored; switching packages retained the
prior pet's queue, frame, velocity and interaction timers; and absent collision
metadata made the full transparent window intercept input.

## Design impact

Adds an immutable core package contract used by BehaviorEngine and the AppKit
adapter. Package publication becomes an explicit session boundary, recorded
by ADR-0012 and both affected evolving design documents.

## Changes

- Separate exact animation lookup from semantic capability fallback.
- Validate/derive supported poses and route only through available bridges.
- Honor `nextAnimation` only when runtime completion remains unclaimed.
- Apply finite positive `pixelsPerBodyUnit` to desktop canvas scale.
- Gate physical interaction on the complete physical capability chain.
- Reset controller/runtime/render transients after successful inspection.
- Fall back from `collisionRect` to `trimRect`.
- Add deterministic contract, scale, pose, next-action, reset-policy and hit
  geometry regressions.

## Compatibility

Format version remains 1. Legacy missing pose values derive from the existing
animation vocabulary; unknown legacy animations are seated. The default
package remains behaviorally equivalent at 220 pixels per body unit. Optional
capabilities now suppress or use the documented semantic fallback instead of
silently displaying idle.

## Test evidence

TR-PACKAGE-20260723-001 preserves the first focused failure where preview
still bypassed package pose routing. TR-PACKAGE-20260723-002 records the
corrected 20 focused and 46 full Swift tests, build/typecheck/core smoke,
schema/package validation, governance fixtures and final governed digest; all
required final checks passed.

## Rollback

Revert this unmerged branch. After merge, supersede ADR-0012 and restore the
previous session as a whole; do not reintroduce silent idle lookup or partial
package publication.

## Revision log

- 2026-07-23: contract decisions and three linked badcases opened for
  implementation on `codex/pet-package-contract`.
- 2026-07-23: first focused run exposed forced preview bypassing a custom idle
  pose; failure preserved as TR-PACKAGE-20260723-001.
- 2026-07-23: separated forced queue replacement from pose bypass, completed
  contract/UI/session integration and marked ISSUE-002 plus BC-002/003/004
  fixed against TR-PACKAGE-20260723-002.
