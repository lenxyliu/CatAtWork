# CHG-20260723-008 — Validate the pushed main diff

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-014
- BC: BC-017
- ADR: ADR-0010
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-005

## Purpose

Ensure the first workflow triggered by the squash merge validates the new
change rather than reopening every immutable baseline record.

## Before: badcase and risk

Local `--all` preflight failed CHG-001 freshness and produced cross-design
revision errors for CHG-002 through CHG-006, even though those historical
paths were not all modified by the future main push.

## Design impact

Push validation is now explicitly incremental. ADR-0010 separates the
one-time baseline operation from normal main evolution.

## Changes

- Pass `github.event.before` to the governance checker on push.
- Rename the workflow step to describe pushed-change validation.
- Add a regression test requiring the before-SHA contract and rejecting a
  workflow `--all` invocation.

## Compatibility

Pull-request validation is unchanged and still uses the exact PR base SHA.
The first existing-main squash merge has a valid `before` commit.

## Test evidence

TR-CI-20260723-005 records the reproduced pre-fix failure, 13 passing
governance tests, full local Swift/package validation and the final hosted PR
checks.

## Rollback

Do not restore `--all` for normal pushes. If GitHub changes push payload
semantics, add a superseding ADR/CHG and a fixture for the replacement base.

## Revision log

- 2026-07-23: fixed after merge preflight exposed deterministic post-merge
  false failures.
