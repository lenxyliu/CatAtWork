# CHG-20260726-005 — Implement the canonical pet asset contract

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-26
- ISSUE: ISSUE-015, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026;
  GitHub #9, #11, #12, #16, #17, #21
- BC: BC-018, BC-020, BC-021, BC-024, BC-025, BC-029, BC-030
- ADR: ADR-0016
- Design: docs/design/ASSET-PIPELINE.md; docs/design/CATPET-CONTRACT.md;
  docs/design/TEST-AND-RELEASE.md;
  docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-ASSET-20260726-001 through TR-ASSET-20260726-019;
  TR-GOVERNANCE-20260726-013 through TR-GOVERNANCE-20260726-014

## Purpose

Define and enforce one canonical source-to-package contract for scale,
authored canvas, anatomical anchors, identity references, endpoint poses,
color, disconnected components and deterministic atlas round-trip while
preserving explicit format-1 compatibility.

## Before: badcase and risk

BC-018/020/021/024/025/029 establish current geometry, hidden action resize,
alpha-derived root, detached-component, endpoint-pose and identity failures.
The format-1 production spec resizes locomotion actions by 1.75×/1.9×,
publishes `bodyScale = 1`, derives pivots from per-frame alpha bounds and
contains no canonical metadata that can fail closed.

## Design impact

This is a strategic asset/package-contract change governed by ADR-0016. It
adds versioned format-2 semantics, updates both affected evolving design
documents and extends the test/release matrix. Format 1 is not reinterpreted.

## Changes

- Added versioned format-2 authoring/package models, JSON schema and a
  governed synthetic fixture.
- Added one fixed 220 px/body-unit scale, fixed authored canvas/safe margin,
  explicit per-frame root/support anchors, identity landmarks/contours/ROIs,
  endpoint pose signatures, sRGB straight-RGBA metadata and an exact reviewed
  disconnected-component policy.
- Added a deterministic Python builder/validator that rejects hidden resize,
  embedded ICC or implicit mode conversion, unsafe anchors, unbound endpoint
  signatures and unmatched component exceptions. It pastes full authored
  canvases without resampling, reopens atlas output and requires equal
  canonical RGBA digests.
- Added Swift format-2 decoding and fail-closed metadata/content import checks,
  including real-alpha safe-margin and 8-connected-component inspection.
- Made format-1 authoring an explicit `--legacy-v1` operation, while retaining
  read-only runtime compatibility for legacy density, unit/non-unit
  `bodyScale`, stored pivots and deterministic missing-pose profiles.
- Added Python/Swift negative and determinism fixtures to hosted CI and kept
  the existing B2 baseline/release oracle active.
- Updated ASSET-PIPELINE, CATPET-CONTRACT, TEST-AND-RELEASE and the changelog.
  No production raster, atlas, format-1 manifest or frozen B1 evidence changed.

## Compatibility

The current production package remains format 1 and is byte-for-byte
unchanged. Format-1 import continues to normalize positive finite package
density, honor stored pivots and `bodyScale`, and derive missing pose metadata
from the accepted deterministic profiles. Missing canonical metadata is never
synthesized or written back.

Legacy `authoringScale` remains available only when the builder is invoked
with explicit `--legacy-v1`; that path emits format 1 and is not a migration
or release signal. Format-2 migration requires fixed-canvas source frames and
all authored canonical metadata, so production migration remains B4 scope.

## Test evidence

- TR-ASSET-20260726-001 preserves the exact pre-change B3 badcases and
  accepted B2 baseline/release oracle.
- TR-ASSET-20260726-002 through 008 preserve incremental Python/Swift/package
  validation while the contract was implemented.
- TR-ASSET-20260726-009 preserves the failed staging-path fixture rerun;
  TR-ASSET-20260726-010 records the corrected 15/15 recovery.
- TR-ASSET-20260726-014 preserves the post-change source-root digest drift
  caused by an authoring README edit; TR-ASSET-20260726-015 records exact
  recovery after removing that non-essential source-root mutation.
- TR-ASSET-20260726-016 records the final 37/37 Python suite, Python/JSON
  syntax, diff check and governed digest
  `0ba6eb93d724560e3499a0b2805084061a14c5022484f5982e8dff3976e069b8`.
- TR-ASSET-20260726-017 records 64/64 Swift tests on fresh build path
  `/private/tmp/catatwork-b3-swift-final2.y8j06f`.
- TR-ASSET-20260726-018 records the Core smoke path and byte-identical current
  package report
  `1ceee00399a52118606e52cb4f0db8be5e80b1adfb98e9b1980876aff4763c3b`.
- TR-ASSET-20260726-019 records the final-digest B2 oracle: baseline exits 0
  with the exact 11 known findings, release exits 1 with those same 11
  errors, and both 6.3 MB reports match their pre-change SHA-256 exactly.
- TR-GOVERNANCE-20260726-013 preserves the initial evidence-metadata failure;
  TR-GOVERNANCE-20260726-014 records the corrected 39-path staged check.

## Rollback

Before merge, revert the proposed format-2 schema, builder/runtime validation,
fixtures and tests together while preserving this CHG, ADR and every TR.
After merge, supersede ADR-0016; never reinterpret format 1 or delete the
accepted evidence chain.

## Revision log

- 2026-07-26: created after the exact clean-start verification, all required
  source reads and pre-change B3/B2 reproduction.
- 2026-07-26: implemented format-2 schema, builder, runtime validation,
  compatibility behavior and synthetic tests without changing production
  content.
- 2026-07-26: preserved a staging-fixture failure and source-root digest
  failure in immutable TRs, corrected both causes and reran on new evidence
  paths.
- 2026-07-26: finalized with the final governed digest, full Python/fresh
  Swift/typecheck/current-package evidence and a byte-identical B2 oracle.
- 2026-07-26: preserved and recovered an initial staged-governance metadata
  failure without changing governed product content.
