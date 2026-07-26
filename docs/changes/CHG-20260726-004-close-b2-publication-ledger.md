# CHG-20260726-004 — Close the B2 publication ledger

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-26
- ISSUE: ISSUE-027; ISSUE-015 through ISSUE-026; GitHub #14 and #15
- BC: BC-030; BC-018 through BC-029
- ADR: none
- Design: docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-GITHUB-20260726-007 through TR-GITHUB-20260726-009;
  TR-GOVERNANCE-20260726-010 through TR-GOVERNANCE-20260726-012

## Purpose

Persist the exact B2 PR head, remote path equality, hosted checks, procedural
review, guarded squash merge, GitHub comments and local-main alignment after
PR #26 accepted the deterministic visual-QA hard gates.

## Before: badcase and risk

The accepted B2 implementation exists on `main`, but its in-repository plan
ledger necessarily still describes the pre-publication checkpoint. The first
local GitHub CLI preflight also failed because `gh` was unavailable, and the
first merge-guard script intentionally stopped on two connector response-shape
false negatives. Omitting those attempts or the accepted merge identity would
make the next batch depend on terminal or chat history.

## Design impact

None. This is a governance-ledger closure only. It does not change runtime
behavior, package metadata, thresholds, production pet assets, B1
classifications, or the B2 report/release policy accepted by PR #26.

## Changes

- Record the failed CLI preflight and the connector-based publication
  recovery.
- Record the failed no-write merge guard and its corrected guarded retry.
- Record PR #26, its exact final head, 42-path remote equality, hosted jobs,
  procedural review, squash merge and #14/#15 comments.
- Mark local ISSUE-027 and BC-030 automated status fixed while leaving GitHub
  #14 and every other child Issue open and unchanged.
- Mark B2 complete and its dependent batches ready but not started.

## Compatibility

No product or package compatibility impact. The closure diff is Markdown-only
and contains no generated QA output, binary artifact, recording or credential.

## Test evidence

- TR-GITHUB-20260726-007: the local `gh` preflight failed before any GitHub
  operation because the binary was absent.
- TR-GITHUB-20260726-008: the first expected-head guard stopped without
  merging on connector response-shape false negatives.
- TR-GITHUB-20260726-009: connector publication, 42-path equality, exact-head
  hosted checks, review, guarded squash merge, #14/#15 comments and local-main
  alignment passed.
- TR-GOVERNANCE-20260726-010: the unchanged B2 final head passed 22 Python
  tests, whitespace, governance, JSON and prohibited-artifact checks.
- TR-GOVERNANCE-20260726-011: a shell command intended to search handoff
  patterns failed during parsing before branch creation or file mutation.
- TR-GOVERNANCE-20260726-012: the complete closure diff passed staged
  whitespace, governance, path and prohibited-artifact checks.

## Rollback

Revert only this closure-ledger update if its publication facts are
inaccurate. Preserve PR #26, the accepted B2 implementation, all GitHub
comments and every immutable failed/passing TR.

## Revision log

- 2026-07-26: created from accepted
  `main@72d2154afbe590654ce5c21be7363d9c67ac267f` before the governed
  closure update.
- 2026-07-26: finalized with the failed/recovered publication attempts, exact
  B2 merge identity and B3 not-started boundary.
