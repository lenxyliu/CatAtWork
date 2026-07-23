# ADR-0010 — Validate each main push as a diff

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-008
- ISSUE: ISSUE-014

## Context

The CI push path used `--all`, a mode intended only for creating the first
baseline. On a later merge it reclassified immutable accepted history as
newly added and demanded that it match the newest digest and design revisions.

## Decision

For a push to `main`, run governance with
`--base "${{ github.event.before }}"`. Keep `--all` available only for an
explicit new-baseline operation. Add a repository test that prevents the
workflow from restoring `--all`.

## Consequences

Post-merge validation checks the exact pushed change and preserves the
immutability of earlier records. A force-push could make the before SHA
non-ancestral; procedural policy forbids force-pushing `main`, and any future
handling for rewritten history requires a superseding ADR.
