# CHG-20260726-002 — Preserve the final B1 publication comment recovery

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-26
- ISSUE: ISSUE-015 through ISSUE-026; GitHub #15
- BC: BC-018 through BC-029
- ADR: none
- Design: docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-GITHUB-20260726-004; TR-GITHUB-20260726-005;
  TR-GOVERNANCE-20260726-003

## Purpose

Preserve the failed and successful attempts to publish the final B1 closure
comment to GitHub #15, and append the accepted closure-PR evidence to the plan.

## Before: badcase and risk

After closure PR #24 merged, the first local script intended to add its exact
merge evidence to #15 failed during JavaScript parsing. GitHub received no
write, but leaving that failed publication attempt outside the governed record
would violate the batch requirement to preserve failed publication runs.

## Design impact

None. This change records publication evidence only. It does not change code,
runtime behavior, package contracts, release policy, production artwork, B1
classifications, or Issue lifecycle state.

## Changes

- Record the failed comment-script parse as TR-GITHUB-20260726-004.
- Record the successful connector retry and comment ID as
  TR-GITHUB-20260726-005.
- Append PR #24's accepted merge and final #15 comment to the plan ledger.

## Compatibility

No product or package compatibility impact. The diff is Markdown-only.

## Test evidence

- TR-GITHUB-20260726-004: failed before the connector call because Markdown
  backticks were not escaped in a JavaScript template literal.
- TR-GITHUB-20260726-005: the safely constructed retry created #15 comment
  `5083176789` with the exact closure merge evidence.
- TR-GOVERNANCE-20260726-003: the five-path Markdown-only diff passed local
  whitespace and governance checks.

## Rollback

Revert only this final evidence publication if its facts are inaccurate. Keep
the accepted PR #23/#24 merges, GitHub comments and prior immutable TRs.

## Revision log

- 2026-07-26: created before recording the failed and recovered #15 comment
  publication attempts.
- 2026-07-26: finalized with separate failed/retry TRs, the accepted PR #24
  merge and the B2 not-started boundary.
