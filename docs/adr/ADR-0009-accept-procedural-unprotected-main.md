# ADR-0009 — Accept procedural control for an unprotected private main

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-007
- ISSUE: ISSUE-013
- Supersedes: ADR-0008

## Context

ADR-0008 paused merging because GitHub Free cannot protect a private
repository. The owner explicitly states that no paid GitHub plan will be
purchased and authorizes proceeding with the recommended cleanup and merge.

## Decision

Keep the repository private and remain on GitHub Free. Accept that `main`
cannot be server-protected. Require procedural use of PRs, manual confirmation
that `governance` and `swift` pass on the final head, squash-only merge, no
force-push and no deletion of `main`.

Record ISSUE-013/BC-016 as `wont-fix`, not fixed. GitHub CLI credentials and
the repository deploy key do not bypass this policy even though the server
cannot enforce it.

## Consequences

Work can continue without subscription cost or public source exposure. An
owner credential can still push directly, delete or force-update `main`; this
risk is knowingly accepted. Every handoff must describe the repository as
procedurally governed, never branch-protected.
