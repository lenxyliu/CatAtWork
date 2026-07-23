# CHG-20260723-006 — Apply available remote merge policy

- Status: partial
- Change-Type: governance
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-013
- BC: BC-016
- ADR: ADR-0008
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-004, TR-CI-20260723-005, TR-GITHUB-20260723-001

## Purpose

Configure the private GitHub repository as close as the current account tier
allows to the planned protected-main workflow, without changing billing or
exposing source.

## Before: badcase and risk

The new private repository allowed merge commits, rebase merges and retained
merged branches. The planned server enforcement state had not been tested
against the account's feature availability.

## Design impact

The release strategy now distinguishes passing checks from server-enforced
branch protection and defines a merge pause when private protection is
unavailable. ADR-0008 prevents silent public-visibility or billing changes.

## Changes

- Disable merge commits and rebase merges.
- Keep squash merge as the only merge method.
- Delete feature branches after merge.
- Attempt and verify private `main` protection through the GitHub API.
- Preserve the HTTP 403 as BC-016/TR-GITHUB-20260723-001.
- Mark PR #1 ready but not mergeable under the planned gate until the owner
  resolves ISSUE-013 or records an explicit exception.

## Compatibility

No source, asset or runtime behavior changes. Existing open PRs remain
available. Squash merging will collapse their implementation commits while
the repository documents retain the detailed evidence chain.

## Test evidence

TR-CI-20260723-004 proves both required checks pass. TR-GITHUB-20260723-001
proves squash-only settings were applied and records that protection itself
is unavailable under GitHub Free for this private repository.

## Rollback

Re-enabling merge/rebase methods is a reversible repository setting but must
use a new CHG/ADR. Do not work around the protection limitation by making the
repository public or changing billing without explicit owner authorization.

## Revision log

- 2026-07-23: squash-only and delete-branch settings applied; main protection
  blocked by account tier.
- 2026-07-23: owner decision is recorded separately by ADR-0009/CHG-007;
  this partial attempt record remains unchanged in meaning.
