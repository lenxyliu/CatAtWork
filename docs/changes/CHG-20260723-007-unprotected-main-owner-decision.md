# CHG-20260723-007 — Record owner acceptance of unprotected main

- Status: complete
- Change-Type: governance
- Strategic-Change: yes
- Owner: lenxyliu
- Created: 2026-07-23
- ISSUE: ISSUE-013
- BC: BC-016
- ADR: ADR-0009
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-005, TR-GITHUB-20260723-002

## Purpose

Implement the owner's explicit decision to keep the repository private, pay
no GitHub subscription fee, and proceed without branch protection.

## Before: badcase and risk

ADR-0008 correctly blocked merge pending an owner decision. Without a
permanent follow-up, later maintainers could either keep work paused or
mistakenly claim the private `main` was protected.

## Design impact

ADR-0009 supersedes the pause with a procedural policy and retains the
unpreventable direct-push/force-push/delete risk as `wont-fix`.

## Changes

- Record the owner decision and accepted risk.
- Keep the repository private and on GitHub Free.
- Require final-head Actions inspection and squash-only PR merges.
- Remove the merge pause without claiming server enforcement.

## Compatibility

No product behavior changes. Repository visibility, credentials and merge
method remain unchanged.

## Test evidence

TR-GITHUB-20260723-002 verifies the private/squash-only remote state and owner
decision. TR-CI-20260723-005 verifies the final head before the authorized
unprotected squash merge.

## Rollback

Enabling a paid plan and branch protection later is allowed through a new
ADR/CHG. Do not rewrite ADR-0008, ADR-0009 or BC-016.

## Revision log

- 2026-07-23: owner explicitly declined paid GitHub and authorized proceeding
  without branch protection.
