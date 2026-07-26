# CHG-20260726-001 — Close the B1 publication ledger

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-26
- ISSUE: ISSUE-015 through ISSUE-026; GitHub #15
- BC: BC-018 through BC-029
- ADR: none
- Design: docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-GITHUB-20260726-001; TR-GOVERNANCE-20260726-001

## Purpose

Persist the accepted B1 squash-merge identity and publication evidence in the
visual-remediation plan after PR #23 merged, without beginning B2 or changing
any B1 classification.

## Before: badcase and risk

The accepted B1 content is on `main`, but the in-repository plan necessarily
still describes the pre-merge publication state because the squash commit did
not exist before PR #23 merged. Leaving that checkpoint stale would make the
next task depend on GitHub or chat history for the accepted base.

## Design impact

None. This is a governance-ledger closure only. It does not change product
code, runtime behavior, package contracts, test/release policy, production
artwork, visual classifications, or Issue lifecycle state.

## Changes

- Record PR #23, its final reviewed head, required hosted checks and accepted
  squash merge commit in the plan ledger.
- Mark B1 complete and B2 ready but not started.
- Preserve the exact GitHub #15 publication and merge comments in a new TR.

## Compatibility

No product or package compatibility impact. The diff is Markdown-only and
contains no generated QA output or binary artifact.

## Test evidence

- TR-GITHUB-20260726-001: PR #23 final head, 28-path diff, hosted checks,
  review, guarded squash merge, #15 evidence and local-main alignment passed.
- TR-GOVERNANCE-20260726-001: the four-path Markdown-only closure diff passed
  whitespace and governance checks without changing the governed-content
  digest.

## Rollback

Revert only the closure-plan update if its publication evidence is inaccurate;
preserve PR #23, GitHub comments and immutable B1 records. Do not revert or
rewrite the accepted B1 evidence to roll back this ledger change.

## Revision log

- 2026-07-26: created before the post-merge plan-ledger update.
- 2026-07-26: finalized with the accepted PR #23 merge and closure-governance
  evidence; B2 remained not started.
