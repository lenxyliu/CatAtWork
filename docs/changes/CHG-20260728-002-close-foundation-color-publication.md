# CHG-20260728-002 — Close foundation color publication evidence

- Status: complete
- Change-Type: documentation
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-28
- ISSUE: ISSUE-016, ISSUE-026; GitHub #10, #21, #15
- BC: BC-019, BC-029
- ADR: ADR-0017
- Design: docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-GITHUB-20260728-004, TR-GITHUB-20260728-005, TR-GOVERNANCE-20260728-012

## Purpose

Close the reviewed publication record for the user-accepted B4 foundation
color prerequisite and provide one bounded next-task route without resuming
interaction in this task.

## Before: badcase and risk

CHG-20260728-001 and TR-ASSET-20260728-023 contained complete local
acceptance, but durable history still needed the exact PR head, hosted job
links, procedural review, guarded squash commit, Issue comment identities,
CHANGELOG entry and final handoff.

The user also observed fast blinking and inconsistent size between actions.
Those observations must remain separate from the accepted color result:
cross-action size is existing ISSUE-017 / BC-020 scope, while blink cause is
not established without a later timing reproduction.

## Design impact

None. This closure changes Markdown only. ADR-0017 and every product,
package, asset and runtime contract remain exactly as merged by PR #32.

## Changes

- Record PR #32 exact head, hosted checks, procedural review and guarded
  squash merge.
- Link the pre-merge and accepted-merge comments on GitHub #10, #21 and #15.
- Add the user-visible foundation color correction to the Unreleased
  changelog.
- Advance the plan ledger and select `NEW_LOCAL_TASK` for any later
  interaction resumption.
- Keep fast-blink and cross-action-size follow-up outside both this closure
  and the completed color prerequisite.

## Compatibility

No compatibility surface changes. Interaction assets remain at checkpoint
`31d8ab14540e856c381613f98f29b540c472ebb8` beneath documentation-only
handoff head `ae6e435c4fbab2d80e9c569f4049b3109758a8a3`. Physical actions,
generated atlases, the runtime package, integration, B5–B8 and release are
unchanged.

## Test evidence

TR-GITHUB-20260728-004 preserves two failed review-orchestration invocations.
TR-GITHUB-20260728-005 records the exact accepted PR and Issue state.
TR-GOVERNANCE-20260728-012 records the closure diff and unchanged governed
product digest.

## Rollback

Revert only this documentation closure. Never remove or rewrite the accepted
PR #32, Issue comments, CHG-20260728-001, ADR-0017, failed TRs or asset
evidence.

## Revision log

- 2026-07-28: created after guarded PR #32 squash merge and accepted Issue
  publication, before the documentation closure PR.
