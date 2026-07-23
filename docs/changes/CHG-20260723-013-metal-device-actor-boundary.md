# CHG-20260723-013 — Wrap the Metal device before actor transfer

- Status: complete
- Change-Type: fix
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-003
- BC: BC-006
- ADR: ADR-0013
- Design: ASYNC-IO
- TR: TR-IO-20260723-005, TR-IO-20260723-006, TR-GOVERNANCE-20260723-002

## Purpose

Make the asynchronous texture cache compile under the repository's oldest
supported hosted Swift 6 toolchain without changing runtime behavior.

## Before: badcase and risk

PR #7 passed locally under Xcode 26.6 but Xcode 16.4 rejected sending the raw
main-actor `MTLDevice` into the cache actor. Unit tests and package validation
were skipped, preventing merge and proving that the sendability adapter was
created on the wrong side of the isolation boundary.

## Design impact

No policy or architecture decision changes. This implements ADR-0013's
reviewed `@unchecked Sendable` framework adapter at the producer boundary:
the main actor creates `MetalDeviceBox`, and only that box enters the actor.

## Changes

- Make `MetalDeviceBox` visible to the main-actor renderer within the module.
- Change `MetalTextureCache` initialization to accept the sendable box instead
  of raw `MTLDevice`.
- Preserve the hosted compile failure and corrected content-matched local
  verification.

## Compatibility

The cache key, byte budget, loader, Metal device instance and rendering output
are unchanged. The source now satisfies both Xcode 16.4's region-isolation
checker and the local Xcode 26.6 compiler.

## Test evidence

TR-IO-20260723-005 preserves the Xcode 16.4 build failure. The corrected
content passed app build, 53 Swift tests, independent typecheck, package and
governance validation in TR-IO-20260723-006. The first staged commit attempt
correctly rejected the missing follow-up CHG and is preserved in
TR-GOVERNANCE-20260723-002.

## Rollback

Revert this follow-up commit together with the texture-cache actor change.
Do not restore transfer of a raw non-Sendable framework existential across an
actor boundary.

## Revision log

- 2026-07-23: created after hosted Xcode 16.4 diagnosed the raw Metal device
  transfer and the local staged gate required an independent follow-up CHG.
