# ADR-0008 — Do not bypass unavailable private-repository protection

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-006
- ISSUE: ISSUE-013

## Context

The repository is required to remain private and `main` is required to use
server-enforced PR/check gates. GitHub Free rejected branch protection with
HTTP 403, while changing billing or visibility would expand cost or exposure.

## Decision

Keep the repository private. Enable every available non-destructive setting:
squash-only merges and automatic feature-branch deletion. Treat unavailable
branch protection as `blocked-external` and pause merges rather than claiming
local hooks provide equivalent protection.

Only the owner may choose GitHub Pro or explicitly change visibility. A
temporary unprotected merge requires a new time-bounded exception CHG/ADR
that names the risk and restoration step.

## Consequences

PR #1 and later work can be prepared and tested but cannot satisfy the planned
remote enforcement gate on the current account tier. No source or archive is
made public implicitly, and the gap remains visible in ISSUE-013/BC-016.
