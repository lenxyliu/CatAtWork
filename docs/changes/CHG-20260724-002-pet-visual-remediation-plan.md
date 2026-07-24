# CHG-20260724-002 — Define the pet visual-remediation execution plan

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-24
- ISSUE: GitHub #15
- BC: none
- ADR: none
- Design: AGENTS.md; docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md
- TR: TR-GOVERNANCE-20260724-002

## Purpose

Turn the visual-defect analysis and proposed repair order into a durable,
cross-task execution plan. The plan must make dependencies, branch scope,
evidence requirements, exit criteria, and handoff state available without
depending on one Codex conversation.

## Before: badcase and risk

GitHub issue #15 and its child issues contained the defect evidence and draft
acceptance thresholds, but they did not define a complete branch/PR sequence.
A future task could start with the wrong subsystem, combine unrelated roots,
repeat expensive asset work, or rely on a chat summary instead of the original
records.

## Design impact

This is a planning and agent-workflow change. It does not approve or implement
production code, package-contract, asset, renderer, runtime, or release-policy
changes. Strategic decisions identified by the plan still require their own
future ADR, design revision, CHG, badcase, and content-matched TR.

## Changes

- Add an evolving visual-remediation plan with source-of-truth boundaries,
  dependency order, bounded implementation batches, per-batch entry and exit
  gates, verification layers, and rollback expectations.
- Define a one-primary-task-per-batch working model and a durable handoff
  protocol based on branch, commit, GitHub issues, repository records, and an
  append-only progress ledger.
- Reference the plan from `AGENTS.md` so a new task discovers it
  automatically.
- Index the new `docs/plans/` record class.

## Compatibility

Existing ISSUE, BC, ADR, CHG, TR, audit, branch, and PR rules are unchanged.
GitHub issue #15 remains the active defect master register. The plan coordinates
future records but does not replace them.

## Test evidence

TR-GOVERNANCE-20260724-002 records whitespace and staged governance checks.
Product tests are not required because this change only adds Markdown planning
and workflow guidance.

## Rollback

Remove the `AGENTS.md` plan reference and stop using the plan for future work.
Preserve this CHG and any progress already recorded in GitHub Issues as
historical evidence.

## Revision log

- 2026-07-24: created and completed with the first durable execution and
  cross-task handoff plan.
