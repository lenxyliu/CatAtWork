# CHG-20260723-005 — Bind record immutability to protected main

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-010
- BC: BC-013
- ADR: ADR-0007
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-003, TR-CI-20260723-004, TR-CI-20260723-005

## Purpose

Allow proposed records to gain final evidence during an unmerged PR while
continuing to prohibit any rewrite or deletion of records accepted by
protected `main`.

## Before: badcase and risk

The pre-push after `cd3395d` rejected branch-only CHG refinements and
simultaneously required those CHGs to link the newest digest-matched TR.
No compliant push was possible.

## Design impact

Evidence lifecycle now has an explicit acceptance boundary: base-tree
membership, not staged diff status. ADR-0007 and TEST-AND-RELEASE define the
local and hosted protected-ref selection.

## Changes

- List immutable paths from the exact protected Git tree.
- Use the PR base SHA in Actions and prefer `origin/main` for staged checks.
- Permit modification of immutable-category files absent from the protected
  base.
- Add regression fixtures for both accepted and unmerged records.
- Relink branch-local CHG-002 through CHG-004 to the fresh TR without deleting
  their earlier evidence.

## Compatibility

No application or asset behavior changes. CI requires full checkout history,
which is already configured for the governance job. Direct Python callers
retain strict behavior unless they explicitly provide a protected set.

## Test evidence

TR-CI-20260723-003 records 12 passing governance fixtures, actual staged
validation against `origin/main`, Swift build/tests and package validation
for the final governed digest. TR-CI-20260723-004 records the authoritative
hosted PR-base validation.

## Rollback

Do not restore status-only immutability. If protected-ref semantics change,
add a superseding ADR/CHG and retain BC-013 and this record as the reason the
boundary exists.

## Revision log

- 2026-07-23: implemented after the first Pillow-provisioning push exposed
  the lifecycle deadlock.
- 2026-07-23: hosted governance passed against the exact PR base in Actions
  run `29985577013`.
- 2026-07-23: linked final-head TR-CI-20260723-005 after the main-push
  workflow changed.
