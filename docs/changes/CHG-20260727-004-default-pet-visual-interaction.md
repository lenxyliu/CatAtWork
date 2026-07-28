# CHG-20260727-004 — Rebuild the default-pet visual interaction family

- Status: blocked-before-production
- Change-Type: asset
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-28
- ISSUE: ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-021,
  ISSUE-022, ISSUE-026; GitHub #9, #10, #11, #12, #16, #17, #21
- BC: BC-018, BC-019, BC-020, BC-021, BC-024, BC-025, BC-029
- ADR: ADR-0015, ADR-0016
- Design: docs/design/ASSET-PIPELINE.md; docs/design/CATPET-CONTRACT.md;
  docs/design/TEST-AND-RELEASE.md;
  docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-ASSET-20260728-018; TR-GOVERNANCE-20260728-008

## Purpose

Reuse the accepted frozen B4 foundation to rebuild exactly the 336 production
frames in `idleEar`, `idleTail`, `groom`, `wave`, `petting`, `earPet`,
`chinPet`, `backPet`, `curious`, `working`, `waiting`, `happy`, `startled`
and `failed`.

## Before: badcase and risk

The isolated pre-change interaction package fails the B2 release oracle with
seven finding families across 5,884 observations: adjacent continuity,
material color, cross-action scale, source/atlas round-trip, root/support,
connected components and identity proxy. The accepted endpoint matrix also
shows that `backPet` declares `seated -> seated` while its actual endpoints
are standing/crouched.

The accepted candidate-9 foundation remains the immutable reference. A fresh
rebuild passed 3,802/3,802 B2 observations and all 14 foundation checks, and
all 216 rebuilt frames compared byte-for-byte with the installed foundation.

## Design impact

This is the bounded B4 interaction production slice already authorized by
ADR-0016 and the visual-remediation plan. It reuses
`Config/DefaultPet/foundation-contract.json` without weakening scale, canvas,
root/support, color, identity, pose, component or deformation rules. No new
ADR is required unless evidence forces a reviewed deviation from ADR-0016.

## Changes

- Added an isolated interaction contract plus deterministic assembly,
  action-scoped B2 validation, direction/component/endpoint gates and
  root/head/fixed-background QA generation.
- Generated 14 eight-pose native-size source sheets and four isolated
  336-frame candidates without resizing or resampling.
- Candidate 4 passes 6,310 B2 observations and all seven custom checks. Its
  `waiting` timing model separates a 0.71-second blink from a 2.71-second
  open-eye dwell inside the 3.43-second loop.
- Did not install any candidate raster. The nine foundation actions, eight
  physical actions, production animation spec, runtime package and generated
  atlases remain untouched by this branch.
- Native review confirmed that the generated source-sheet color is the target
  while the frozen palette-normalized production appearance is not. For
  `waiting` pose 0, the frozen pull rewrites 99.205807% of opaque pixels and
  moves the dark-material median by ΔE00 7.225664.

## Blocking design evidence

The new user evidence requires a reviewed correction to the accepted
foundation color target or its normalization under ADR-0016. An
interaction-only exception is illegal because all 14 actions must use exact
frozen seated endpoints and would visibly flash at those endpoints. This CHG
does not broaden scope, create an ADR or retouch the nine foundation actions;
it stops before production installation and hands the prerequisite to a
separate foundation color-correction batch.

## Compatibility

This slice does not modify the legacy runtime default package, generated
atlases, package format, runtime behavior, B5 timing, B6 rendering or B7 gaze
behavior. It is not the B4 physical or integration slice and does not release
or publish a full format-2 package.

## Test evidence

- TR-ASSET-20260728-001 and TR-ASSET-20260728-002 preserve two failed
  filename-format comparison commands; their failures did not modify the
  repository.
- TR-ASSET-20260728-003 records the successful candidate-9 oracle
  reproduction, byte-identical 216-frame comparison and isolated interaction
  badcase reproduction.
- TR-ASSET-20260728-004..016 preserve each rejected generation, direction,
  execution, native-audit and timing candidate without overwriting failures.
- TR-ASSET-20260728-017 records candidate 4's automated pass and the
  source-effect versus frozen production-color rejection that blocks native
  acceptance.
- TR-GOVERNANCE-20260728-004 preserves the expected freshness failure;
  TR-ASSET-20260728-018 binds the blocked checkpoint's passing automated
  evidence to the current governed-content digest.
- TR-GOVERNANCE-20260728-005/006/007 preserve three follow-up
  metadata/reference construction failures before the successful staged
  governance rerun.
- TR-GOVERNANCE-20260728-008 records the successful 31-path staged
  governance execution at the same governed-content digest.
- TR-GITHUB-20260728-002 preserves the first push failure caused by the
  requested sibling checkpoint lagging the accepted foundation-closure main
  commit; the checkpoint must be rebased before publication.
- Production install/diff/LFS, full Python, fresh-path Swift, final package,
  PR, hosted checks and merge were skipped because the visual prerequisite
  failed before staging rasters.

## Rollback

Before merge, revert only the new interaction support, 336 scoped source
frames and current proposed CHG/TR/plan records while preserving every
historical ISSUE, BC, ADR, CHG and TR. After merge, supersede this record; do
not rewrite accepted evidence.

## Revision log

- 2026-07-28: created on `codex/default-pet-visual-interaction` at exact base
  `83e05f06ebbf2d48b8c75bd46cdf408196be8464` after the required reads,
  candidate-9 oracle reproduction and scoped interaction badcase reproduction,
  before production asset changes.
- 2026-07-28: preserved candidates 1–4 and stopped before production
  installation after native review confirmed that the accepted effect-sheet
  color is changed materially by the frozen foundation palette pull. A
  separate reviewed foundation color correction is now a prerequisite.
