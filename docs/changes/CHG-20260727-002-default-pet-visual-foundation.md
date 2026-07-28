# CHG-20260727-002 — Rebuild the default-pet visual foundation

- Status: review
- Change-Type: asset
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-27
- ISSUE: ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-021,
  ISSUE-022, ISSUE-026; GitHub #9, #10, #11, #12, #16, #17, #21
- BC: BC-018, BC-019, BC-020, BC-021, BC-024, BC-025, BC-029
- ADR: ADR-0015, ADR-0016
- Design: docs/design/ASSET-PIPELINE.md; docs/design/CATPET-CONTRACT.md;
  docs/design/TEST-AND-RELEASE.md;
  docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-ASSET-20260727-001 through TR-ASSET-20260727-020;
  TR-GOVERNANCE-20260728-001, TR-GOVERNANCE-20260728-002

## Purpose

Freeze the B4 canonical identity, 220 px/body-unit scale, authored canvas,
anatomical root/support tracks, endpoint-pose templates, material references,
comparable ROIs, action semantics and reviewed deformation budgets, then
rebuild only the 216 production frames in `idle`, `sitToStand`, `standToSit`,
`lieDown`, `getUp`, `walkLeft`, `walkRight`, `runLeft` and `runRight`.

## Before: badcase and risk

The accepted B2 release oracle reports geometry continuity, color, hidden
scale, source/atlas round-trip, root/support, disconnected-component and
identity-proxy findings in the scoped foundation actions. The legacy source
spec applies action-level scale factors to locomotion and does not carry the
accepted ADR-0016 fixed-canvas/root/identity metadata. Rebuilding actions
without one frozen cross-action system would repeat the drift captured by
BC-018/019/020/021/024/025/029.

## Design impact

This is the bounded B4 foundation production slice already authorized by
ADR-0016 and the visual-remediation plan. It must implement the accepted
format-2 contract without changing its scale, color, component, endpoint or
source-to-atlas semantics. No new ADR is required unless evidence forces a
reviewed deviation from ADR-0016.

## Changes

- Added one governed foundation contract covering the canonical four-view
  identity, 220 px/body-unit scale, 665×737 authored canvas, anatomical
  root/support tracks, seated/standing/lying endpoint templates, comparable
  material ROIs, action semantics and reviewed deformation budgets.
- Added deterministic build, action-scoped release-validation and QA-sheet
  tools with negative fixtures for material-group collapse and absolute
  locomotion-facing reversal.
- Rebuilt exactly the 216 production source frames in `idle`, `sitToStand`,
  `standToSit`, `lieDown`, `getUp`, `walkLeft`, `walkRight`, `runLeft` and
  `runRight` without action-level or per-frame resize.
- Rejected candidate 6 after the user-observed coat-identity collapse and
  direction reversal, retained that failure, then accepted candidate 9 only
  after independent canonical light/warm/dark and absolute-facing gates
  passed.
- Produced immutable root/head-aligned sheets, five-loop artifacts,
  deterministic metrics and native fixed-background review evidence outside
  production paths.
- Preserved all 544 unscoped source frames, the runtime default package,
  animation spec and generated atlas output byte-for-byte.

## Compatibility

The foundation slice must retain the accepted B3 package contract and format-1
read compatibility. It is not the B4 integration/full-package rebuild and
must not update `Sources/CatAtWork/Resources/DefaultPet.catpet`. Interaction,
physical, B5 timing, B6 rendering and B7 gaze work remain out of scope.

## Test evidence

- TR-ASSET-20260727-001 preserves the first pre-change B2 oracle execution,
  which used the wrong Python/Pillow toolchain and therefore did not reproduce
  the accepted byte-level evidence.
- TR-ASSET-20260727-002 records the clean retry with the accepted
  Python 3.9.6/Pillow 11.3.0 toolchain and the scoped foundation badcases.
- TR-ASSET-20260727-003 preserves the non-destructive `git lfs install`
  refusal to replace the governed pre-push hook.
- TR-ASSET-20260727-004 records successful filter initialization without hook
  replacement and verifies the existing governed hook delegates to Git LFS.
- TR-ASSET-20260727-005 freezes and validates the four-view identity,
  scale/canvas/root/pose/color/action-family foundation against the exact B2
  threshold values and accepted B3 contract.
- TR-ASSET-20260727-006 through TR-ASSET-20260727-014 preserve rejected build,
  extraction, metric and native-style candidates without rewriting any
  failure.
- TR-ASSET-20260727-015 preserves candidate 6's native color and
  locomotion-facing rejection, including the user's observation; the
  fixed-background no-displacement behavior remains explicitly assigned to
  ISSUE-019/B5 rather than changed here.
- TR-ASSET-20260727-016 through TR-ASSET-20260727-019 preserve two native
  harness build failures and the candidate 7/8 validation failures.
- TR-ASSET-20260727-020 accepts candidate 9: 3,802/3,802 action-scoped B2
  observations, 14/14 foundation checks, 15 targeted and 40 full Python
  tests, 64 fresh-path Swift XCTest cases, current-package validation, exact
  deterministic rebuild, LFS verification for all 216 rasters and at least
  five native fixed-background loops for every scoped looped action.
- TR-GOVERNANCE-20260728-001 preserves the rejected split-commit hook
  execution; TR-GOVERNANCE-20260728-002 records the corrected complete staged
  branch check from the unchanged B3 closure base.
- Hosted final-head governance/Swift evidence and reviewed PR acceptance are
  pending.

## Rollback

Before merge, revert only the new foundation references, scoped source frames,
validation support and current CHG/TR/plan records while preserving all
historical evidence. After merge, supersede this record; do not delete or
rewrite production history, accepted ADRs, badcases or failed TRs.

## Revision log

- 2026-07-27: created on `codex/default-pet-visual-foundation` after the
  required source/Issue reads, clean-start verification, accepted B2 oracle
  reproduction and scoped badcase reproduction, before production artwork
  changes.
- 2026-07-27: froze the governed B4 foundation contract before any production
  raster change.
- 2026-07-28: preserved candidate 6's user-visible color and direction
  rejection, added independent material-identity and absolute-facing gates,
  and accepted candidate 9 locally with all scoped production, determinism,
  Python, Swift, native-review and non-scope checks passing.
