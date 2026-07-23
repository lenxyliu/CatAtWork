# ADR-0007 — Bind evidence immutability to the protected base

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-005
- ISSUE: ISSUE-010

## Context

ADR-0001 defines CHGs and other accepted evidence as immutable after merge.
The initial checker instead froze any record shown as modified by the current
diff. That made it impossible for an unmerged multi-commit PR to link a fresh
TR after governed content changed.

## Decision

Use the PR base SHA as the authoritative set of accepted immutable paths. For
local staged checks, prefer `refs/remotes/origin/main`, then local `main`, then
`HEAD`. A proposed record absent from that base may be refined before merge;
a record present in that base may not be modified or deleted.

Every test execution still receives a new TR identity. Refinement may add the
new TR link to a proposed CHG but must not rewrite the earlier execution
record. CI remains authoritative because it resolves the exact PR base SHA.

## Consequences

Multi-commit PRs can converge on a digest-matched evidence chain without
weakening records already accepted by `main`. Local checks depend on an
up-to-date `origin/main`; CI catches any stale local view. Once this ADR is
merged, changing it requires a new superseding ADR rather than editing it.
