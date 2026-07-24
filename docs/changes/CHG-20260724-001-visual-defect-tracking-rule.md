# CHG-20260724-001 — Make GitHub Issues the visual-defect source of truth

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: repository maintainers
- Created: 2026-07-24
- ISSUE: GitHub #15
- BC: none
- ADR: none
- Design: AGENTS.md
- TR: TR-GOVERNANCE-20260724-001

## Purpose

Make defect capture durable across analysis sessions. Every newly observed
pet-animation defect must be created or updated in GitHub Issues before the
analysis continues, and the visual-defect master register must remain current.

## Before: badcase and risk

Visual findings existed in chat, local recordings, and temporary analysis
artifacts without one durable register. Later work could omit a finding,
duplicate an issue, erase failed evidence, or start a fix before the analysis
and acceptance criteria were complete.

## Design impact

This is an agent-workflow governance rule only. It does not change the runtime,
asset package, production artwork, release contract, privacy model, or user
behavior.

## Changes

- Declare GitHub Issues in `lenxyliu/CatAtWork` as the active defect source of
  truth and GitHub issue `#15` as the master visual-defect register.
- Require search-before-create, append-only evidence, fact/hypothesis
  separation, measurable acceptance criteria, and content-matched verification.
- Preserve the boundary between analysis authorization and implementation
  authorization.
- Prohibit publication of private screen content and local absolute paths.

## Compatibility

Existing local ISSUE, BC, CHG, TR, ADR, and audit governance remains unchanged.
GitHub Issues provide the active defect work queue; repository records remain
required when a later implementation invokes the existing change rules.

## Test evidence

TR-GOVERNANCE-20260724-001 records the content-matched governance and
whitespace checks. No product test is required because the change only updates
Markdown agent instructions.

## Rollback

Revert the `AGENTS.md` section while preserving this CHG and GitHub issue `#15`
as historical evidence.

## Revision log

- 2026-07-24: created before adding the durable defect-analysis rule.
- 2026-07-24: completed after the rule was added and governance validation
  passed.
