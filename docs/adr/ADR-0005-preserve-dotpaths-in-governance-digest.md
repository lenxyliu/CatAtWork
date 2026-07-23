# ADR-0005 — Preserve repository dotpaths in governance digests

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-003
- ISSUE: ISSUE-008

## Context

The governance digest is the freshness key for test records. Its path
normalizer used `lstrip("./")`, which treats the argument as a set of
characters and silently removed the leading dot from `.github`, `.githooks`,
`.gitignore` and `.gitattributes`. These governed files were therefore absent
from the digest.

## Decision

Remove only repeated literal `./` prefixes and then leading `/` characters.
Preserve every other dot in a repository-relative path. Unit tests must prove
both classification of dot-prefixed governed paths and digest invalidation
when a workflow is created or changed.

## Consequences

Changes to workflow, hook and root dotfile policy now stale older TRs as
intended. The first corrected digest is intentionally different from every
baseline digest created by the faulty normalizer; a new passing TR is
required.
