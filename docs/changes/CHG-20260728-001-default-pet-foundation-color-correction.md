# CHG-20260728-001 — Correct the default-pet foundation color target

- Status: review
- Change-Type: asset
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-28
- ISSUE: ISSUE-016, ISSUE-026; GitHub #10, #21
- BC: BC-019, BC-029
- ADR: ADR-0016, ADR-0017
- Design: docs/design/ASSET-PIPELINE.md; docs/design/CATPET-CONTRACT.md;
  docs/design/TEST-AND-RELEASE.md;
  docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-ASSET-20260728-019, TR-ASSET-20260728-020, TR-ASSET-20260728-021, TR-ASSET-20260728-022, TR-ASSET-20260728-023, TR-GOVERNANCE-20260728-009, TR-GOVERNANCE-20260728-010, TR-GOVERNANCE-20260728-011

## Purpose

Correct only the accepted B4 foundation color target and deterministic
normalization so native production frames match the user-accepted generated
effect-sheet appearance. Rebuild exactly the existing 216 foundation frames
in `idle`, `sitToStand`, `standToSit`, `lieDown`, `getUp`, `walkLeft`,
`walkRight`, `runLeft` and `runRight`.

## Before: badcase and risk

The accepted candidate-9 foundation passes its frozen palette checks, but the
later interaction native review proved that the frozen palette is not the
accepted visual target. On accepted `waiting` source-effect pose 0, the
existing `fixed-canonical-material-palette-pull` changes 68,203 of 68,749
visible pixels (99.205807%) and moves the dark-material median by ΔE00
7.225664. The native seated endpoint equals production `idle/000.png`, and
the preview/repository Metal sRGB paths are byte-identical, so the mismatch is
authored color rather than a renderer or display-profile hypothesis.

Changing only interaction frames would create a visible flash at the exact
frozen seated endpoints. Removing normalization entirely is also invalid: an
isolated spike against the preserved candidate-9 sources fails 36 B2 material
observations. The prerequisite therefore belongs to the foundation color
contract and must preserve every non-color ADR-0016 invariant.

## Design impact

ADR-0017 supersedes only ADR-0016's previously accepted foundation color
target/normalization choice. The sRGB RGBA8 straight-alpha source declaration,
identity source-to-atlas conversion, fixed scale/canvas, safe margin,
root/support tracks, identity rig, pose/bridge signatures, component policy,
deformation/facing rules and no-resize/package rules remain unchanged.

## Changes

- Add a governed source-effect-to-authored color oracle tied to the accepted
  effect source by content hash, per-material CIEDE2000 limits and independent
  local-detail retention limits.
- Replace the 80% frozen-palette pull with one package-global
  detail-preserving material correction: a 2:3 source/effect-target
  low-frequency base plus seven-tenths reinjection of the source residual
  from an exact 5×5 same-material local mean. Prohibit manual per-action or
  per-frame tuning.
- Rebuild only the nine foundation actions / 216 production frames from the
  preserved candidate-9 source oracle.
- Extend deterministic validation and negative fixtures for the accepted
  source-effect mapping and for non-color byte/alpha invariance.
- Produce native loop evidence for `idle`, `walkLeft`, `walkRight`,
  `runLeft` and `runRight` and require direct user color acceptance.

## Compatibility

The format-2 package contract and format-1 read compatibility remain
unchanged. Interaction frames remain preserved but are not installed or
resumed. Physical actions, generated atlases, the runtime default package,
integration, B5–B8 and release work remain out of scope.

## Test evidence

Pre-change reproduction confirmed the exact
68,203/68,749 changed-pixel badcase, dark-material ΔE00 7.225664, identical
native/repository Metal sRGB sources, identical seated endpoint, and a fresh
candidate-9 oracle rebuild with 3,802/3,802 B2 observations, 14/14 custom
checks and zero mismatches across all 216 frames. Two failed ad-hoc report
summary probes and one failed no-normalization B2 invocation are retained for
TR-ASSET-20260728-019 rather than overwritten. TR-ASSET-20260728-020 retains
the later wrong-path, orchestration and first fresh-Swift failures; their
independent corrected reruns are reserved for the final content-matched
acceptance TR.

The first equal-weight correction is rejected evidence, not acceptance:
TR-ASSET-20260728-021 records that it reduced same-material local L* gradient
RMS to roughly one half and failed direct native user review despite passing
median ΔE and B2. The replacement detail-preserving oracle passes its frozen
effect spike with ΔE00 `0.826423` light, `2.947122` warm and `0.389036` dark
and gradient-retention ratios `1.010780`, `0.990451` and `1.013864`.
TR-ASSET-20260728-023 records the content-matched acceptance: 3,802/3,802 B2,
15/15 foundation, 12/12 color/detail oracle, 216/216 color-only and LFS,
6 targeted plus 43 full Python, an independent 64/64 fresh Swift retry,
byte-identical deterministic double packages and direct native user color
acceptance. TR-ASSET-20260728-022 preserves the preceding cache-test timing
failure and two corrected command assertions.

The user's native observations of fast blinking and cross-action size
inconsistency remain outside this color-only change. The latter is the
existing GitHub #11 / ISSUE-017 / BC-020 scope. Blink attribution requires a
separate timing reproduction; the current batch changes neither the authored
animation spec nor the runtime clock.

## Rollback

Before merge, restore only the proposed color-contract/tool/frame changes
from this branch while preserving this CHG, ADR-0017, all failed evidence and
accepted historical records. After merge, supersede this record and rebuild
from the accepted candidate-9 source oracle; never rewrite ADR-0016 or prior
CHG/TR history.

## Revision log

- 2026-07-28: created from exact clean
  `main@4011d2d8c8fc4559ee1da911a8b9b29fd720d16f` after all required reads,
  exact blocker reproduction and fresh candidate-9 oracle reproduction,
  before production or implementation changes.
- 2026-07-28: retained the first equal-weight-pull candidate as failed
  evidence after direct native review found visibly flattened fur detail;
  color-location and detail-retention acceptance are now separate required
  gates.
- 2026-07-28: replaced the rejected equal-weight pull with the fixed
  same-material local-detail rule and added bounded gradient-retention
  evidence before rebuilding production a second time.
- 2026-07-28: the user accepted the detail-preserving native instance's
  color. Recorded fast-blink and cross-action-size observations separately as
  non-color follow-up scope, retained the rejected native instance closure,
  and advanced the correction to review after content-matched local checks.
