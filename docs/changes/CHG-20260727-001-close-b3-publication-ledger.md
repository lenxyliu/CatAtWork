# CHG-20260727-001 — Close the B3 publication ledger

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-27
- ISSUE: ISSUE-015, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026
- BC: BC-018, BC-020, BC-021, BC-024, BC-025, BC-029, BC-030
- ADR: ADR-0016
- Design: docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-GITHUB-20260727-001; TR-GOVERNANCE-20260727-001

## Purpose

Persist the exact B3 PR head, remote scope, hosted checks, procedural review,
guarded squash merge and scoped GitHub Issue evidence after PR #28 accepted
the canonical pet asset/package contract.

## Before: badcase and risk

The format-2 implementation is accepted on `main`, but the in-repository plan
ledger necessarily describes the pre-publication checkpoint. Without a
governed closure, the final merge identity, hosted job URLs and fourteen
scoped Issue comment identities would exist only in GitHub/task history.

## Design impact

None. This is a Markdown-only publication ledger. It does not change
ADR-0016, the accepted format-2 contract, format-1 compatibility, production
pet content, B2 thresholds, runtime behavior or release policy.

## Changes

- Recorded PR #28 exact base/final head, one-commit/40-path scope, hosted
  governance/Swift URLs and durations, procedural review and guarded squash.
- Recorded all pre-merge and accepted-merge comments on #9/#11/#12/#16/#17,
  #21 and master register #15.
- Marked B3 complete at accepted
  `main@484fa7789d0a72423e8a1c89926e78d64de047b2`.
- Marked B4 unblocked but `ready-not-started`; no branch, production frame or
  B4 evidence was created.

## Compatibility

No product/package compatibility impact. B3 remains accepted exactly as
merged; no legacy or canonical package is read, converted or written.

## Test evidence

- TR-GITHUB-20260727-001 records exact remote head/scope equality, hosted
  jobs, review `4782406719`, guarded merge identity and all fourteen Issue
  comment links.
- TR-GOVERNANCE-20260727-001 records the complete Markdown-only closure scope,
  unchanged governed digest and prohibited-artifact scan.

## Rollback

Revert only this Markdown-only closure if its publication identities are
inaccurate. Never rewrite accepted ADR-0016, CHG-20260726-005 or its immutable
TR chain.

## Revision log

- 2026-07-27: created from accepted
  `main@484fa7789d0a72423e8a1c89926e78d64de047b2` before the B3
  publication-ledger closure.
- 2026-07-27: finalized with exact PR #28 publication, scoped Issue evidence,
  local-main alignment and the B4 not-started boundary.
