# CHG-20260726-003 — Add deterministic visual-QA hard gates

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-26
- ISSUE: ISSUE-027; ISSUE-015 through ISSUE-026; GitHub #14
- BC: BC-030; BC-018 through BC-029
- ADR: ADR-0015
- Design: docs/design/TEST-AND-RELEASE.md; docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-VISUAL-20260726-001 through TR-VISUAL-20260726-007;
  TR-GOVERNANCE-20260726-004 through TR-GOVERNANCE-20260726-009;
  TR-GITHUB-20260726-006

## Purpose

Turn the accepted B1 visual, motion and render failures into deterministic,
machine-readable baseline and release decisions without modifying runtime
behavior or production pet artwork.

## Before: badcase and risk

BC-030 reproduces the current validator returning success for asset
2026.07.23.6 while BC-018 through BC-027 and BC-029 establish independent
content-matched failures. The legacy JSON lacks normalized finding IDs,
threshold provenance, waiver identities and a fail-closed release mode.

## Design impact

This is a strategic test/release-policy change governed by ADR-0015 and the
new visual-QA section of `docs/design/TEST-AND-RELEASE.md`. It defines a
versioned report and supplemental evidence contract but does not change the
`.catpet` package format or metadata; therefore `CATPET-CONTRACT.md` is not
revised.

## Changes

- Added a deterministic report schema and normalized JSON serializer.
- Implemented exact-known-failure baseline mode and fail-closed
  release mode.
- Added explicit action contracts, threshold provenance and
  structurally validated waivers.
- Covered static package/source metrics and required supplemental
  runtime evidence families.
- Added a clean fixture plus 15 negative fixtures spanning every implemented
  metric family.
- Updated hosted validation to execute baseline mode and prove the current
  known-defective package cannot release-pass.

## Compatibility

The legacy `validate_high_frame_pet.py` invocation remains available for
callers that require the old package-only report. The new B2 command is an
additional release-policy gate. No runtime source, manifest field, package
asset, atlas or authoring frame changes.

## Test evidence

- TR-VISUAL-20260726-001: red reproduction; legacy validator exited 0 and
  reported `ok: true` for the known-defective package.
- TR-VISUAL-20260726-002/006: initial and final Python fixture suites passed;
  the final run covered 22 tests and all 15 negative families.
- TR-VISUAL-20260726-003/004: current package passed the exact baseline set
  and was rejected by release mode with 11 unwaived errors.
- TR-VISUAL-20260726-005: identical full inputs produced byte-identical
  normalized reports.
- TR-VISUAL-20260726-007: fresh-path Swift suite passed 57/57.
- TR-GOVERNANCE-20260726-004..008 preserve the failed evidence-digest/staged
  checks, their recoveries and the successful staged implementation
  checkpoint.
- TR-GITHUB-20260726-006 records the content-matched evidence comments on
  GitHub #14 and #15.
- TR-GOVERNANCE-20260726-009 records the final committed branch verification
  and artifact exclusion.

## Rollback

Revert the new visual-QA command, fixtures and workflow invocation together
while preserving this CHG, ADR, BC and every TR. The rollback restores the
legacy acceptance gap and therefore may not be used to publish a release
candidate without a superseding policy decision.

## Revision log

- 2026-07-26: created before implementation after reproducing BC-030 on the
  exact accepted B2 base.
- 2026-07-26: finalized at local implementation checkpoint
  `32203ad88eecbe837a3965f76476bb33566c0a3f` after all B2 exit gates and
  GitHub evidence publication; hosted PR acceptance remains the next task.
