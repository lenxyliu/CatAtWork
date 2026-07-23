# CHG-20260723-012 — Move package and texture work off the main actor

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-003
- BC: BC-005, BC-006
- ADR: ADR-0013
- Design: ASYNC-IO
- TR: TR-IO-20260723-001, TR-IO-20260723-002, TR-IO-20260723-003, TR-IO-20260723-004, TR-IO-20260723-005, TR-IO-20260723-006, TR-IO-20260723-007

## Purpose

Keep import, archive processing, image validation and texture decoding from
blocking AppKit while making process output and decoded texture memory bounded.

## Before: badcase and risk

The UI synchronously traversed and decoded packages; child processes could fill
unread pipes before the parent started reading; each frame URL could trigger a
new synchronous Metal decode; and package replacement had no resource-cache
invalidation boundary.

## Design impact

Introduces one asynchronous package-publication boundary, one cancellation and
timeout-aware process runner, a generic actor-isolated decoded-byte LRU, and a
session-keyed Metal adapter. ADR-0013 and ASYNC-IO define ownership and
cancellation semantics.

## Changes

- Add cancellation-propagating detached execution for package inspection and
  the complete install transaction.
- Drain merged process output before waiting, retain only bounded diagnostics,
  enforce timeout/cancellation with forced-termination fallback, and remove
  every prior wait-before-drain call.
- Enforce compressed/uncompressed size, entry count, nesting depth, image
  dimensions and archive-processing time; reject traversal and symlink entries
  before extraction and clean staging on every exit.
- Publish startup/import results on the main actor only when their load
  generation is still current; cancel superseded imports.
- Add a generic actor-isolated byte-bounded LRU with hits, in-flight
  coalescing, deterministic eviction and namespace invalidation.
- Decode Metal textures off-main, key them by package session and canonical
  path, enforce a 128 MiB decoded-byte ceiling and reject stale completions.
- Add seven focused async/process/cache regressions and update the ZIP install
  smoke harness for async installation and symlink rejection.

## Compatibility

The `.catpet` format and installed package layout do not change. Application
callers become asynchronous. A not-yet-decoded frame is transparent instead of
blocking the display callback; once decoded, it is reused within the current
session. CLI validators retain the synchronous inspection primitive.

## Test evidence

TR-IO-20260723-001 preserves the first app-target compile failure caused by a
missing optional type annotation. TR-IO-20260723-002 preserves the subsequent
optional-process compile failure in the force-kill fallback. Passing evidence
was recorded by TR-IO-20260723-004. TR-IO-20260723-003 preserves a
concurrency-test failure that incorrectly assumed which simultaneous waiter
would reach the actor first. TR-IO-20260723-005 preserves the hosted Xcode
16.4 actor-transfer compile failure. TR-IO-20260723-006 records corrected
content-matched local build, tests, typecheck, package and governance evidence;
the hosted rerun remains the merge gate. TR-IO-20260723-007 preserves a local
normal-sandbox attempt rejected by SwiftPM's nested sandbox; it does not replace
the external-execution pass in TR-IO-20260723-006.

## Rollback

Before merge, revert this branch. After merge, revert the whole change and
supersede ADR-0013; do not restore the wait-before-drain process ordering.

## Revision log

- 2026-07-23: implementation opened with ISSUE-003 and both independent
  badcases in progress.
- 2026-07-23: first focused build reached the app publication boundary and
  exposed an untyped optional expression; failure preserved as
  TR-IO-20260723-001.
- 2026-07-23: strengthened cancellation with a force-kill fallback; its first
  compile exposed an optional-process binding error, preserved as
  TR-IO-20260723-002.
- 2026-07-23: all focused behaviors except an order-dependent coalescing
  assertion passed; the invalid test assumption is preserved as
  TR-IO-20260723-003.
- 2026-07-23: completed background publication, bounded archive processing,
  generation-safe import, 128 MiB session texture cache and all regression/
  smoke/governance evidence; ISSUE-003 and BC-005/006 fixed by
  TR-IO-20260723-004.
- 2026-07-23: PR #7 Xcode 16.4 rejected sending a raw main-actor `MTLDevice`
  to the cache actor. Reopened the unmerged CHG and returned ISSUE/BC status to
  fixed-unverified; failure preserved as TR-IO-20260723-005.
- 2026-07-23: moved `MetalDeviceBox` construction before the actor boundary;
  full content-matched verification passed in TR-IO-20260723-006 and the CHG
  returned to complete pending hosted PR checks.
