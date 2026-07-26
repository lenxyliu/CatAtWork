# CHG-20260724-003 — Establish the current-build pet visual baseline

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-24
- ISSUE: ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-019, ISSUE-020, ISSUE-021, ISSUE-022, ISSUE-023, ISSUE-024, ISSUE-025, ISSUE-026
- BC: BC-018, BC-019, BC-020, BC-021, BC-022, BC-023, BC-024, BC-025, BC-026, BC-027, BC-028, BC-029
- ADR: none
- Design: docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-VISUAL-20260724-001 through TR-VISUAL-20260724-011; TR-GITHUB-20260724-003; TR-GOVERNANCE-20260724-005

## Purpose

Create a content-matched evidence baseline for every visual-remediation child
Issue before any product, package-contract, runtime, renderer, or production
asset change begins.

## Before: badcase and risk

GitHub #9–#14 and #16–#21 contain a mixture of current package measurements,
historical recordings, source-path hypotheses, and unverified renderer risks.
Without a clean build and evidence tied to the accepted commit and exact
default-pet content digest, implementation could target a historical symptom,
merge distinct root scopes, or claim a current defect from stale evidence.

## Design impact

None. This change records analysis, reproduction contracts, immutable test
runs, and the B1 plan checkpoint. It does not change application code,
runtime behavior, schemas, package metadata, release policy, production
artwork, or the canonical default-pet package.

## Changes

- Allocated ISSUE-015..026 and BC-018..029 for all 12 scoped GitHub defects.
- Classified #9–#14, #16–#19 and #21 as `current-confirmed`; classified #20
  as `historical-regression`; no scoped Issue remains `pending-risk`.
- Recorded the accepted commit, clean Universal app identity, package version
  and package content digest.
- Recorded content-matched contacts, loops, endpoint matrix, component scan,
  color/geometry metrics, synchronized locomotion/cadence trace, Metal
  render-delay reproduction and gaze/body comparison.
- Bound 744 frame hashes, 62 endpoint hashes and 15 component hits back to the
  production atlas pixels.
- Appended evidence comments to every child Issue and GitHub #15 and updated
  the B1 plan checkpoint.

## Compatibility

No product or package compatibility impact. Generated QA previews, temporary
diagnostic probes, build products, raw recordings, and private desktop content
remain outside Git.

## Test evidence

- TR-VISUAL-20260724-001: failed; build script was not executable.
- TR-VISUAL-20260724-002: partial; Universal build assembled but File Provider
  metadata blocked signing.
- TR-VISUAL-20260724-003: passed; clean Universal app, signature and embedded
  package identity verified.
- TR-VISUAL-20260724-004: failed visual acceptance; current validator remained
  green while content-matched static scopes failed.
- TR-VISUAL-20260724-005: passed 57/57 Swift tests.
- TR-VISUAL-20260724-006/007: failed QA probe compiles, preserved separately.
- TR-VISUAL-20260724-008: runtime probe executed; locomotion and cadence
  acceptance failed.
- TR-VISUAL-20260724-009: partial; delay injection failed, current gaze/body
  orthogonality passed.
- TR-VISUAL-20260724-010/011: passed native inspection and static pixel
  binding.
- TR-GITHUB-20260724-003: passed all 13 requested Issue updates.
- TR-GOVERNANCE-20260724-005: final diff/governance verification.

## Rollback

Before merge, revert the B1 documentation commit if the evidence contract is
rejected; GitHub comments and executed TR history remain append-only. After
merge, supersede this record; do not rewrite accepted ISSUE, BC, CHG or TR
history.

## Revision log

- 2026-07-24: created before the first non-trivial B1 repository edit.
- 2026-07-24: finalized after the clean build, all scoped reproductions, stable
  ISSUE/BC allocation, GitHub updates and plan-ledger checkpoint.
