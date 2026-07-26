# ADR-0015 — Use deterministic baseline and release visual-QA decisions

- Status: proposed
- Date: 2026-07-26
- CHG: CHG-20260726-003
- ISSUE: ISSUE-027; GitHub #14

## Context

The accepted B1 package contains confirmed visual, motion and rendering
failures while the legacy validator exits successfully. Static image metrics
alone cannot cover cadence, locomotion, asynchronous render snapshots or
gaze/body orthogonality, and warning-bearing output has no stable identity for
comparison or waiver review.

## Decision

Adopt a versioned deterministic visual-QA report whose normalized bytes are a
function of input content rather than filesystem paths, wall-clock time or
host ordering. Every result names the content digest, tool versions,
package/action/frame identity, metric, observed value, threshold, threshold
source and optional waiver identity.

Use two explicit modes:

- `baseline` passes only when the normalized unwaived finding-ID set equals
  the reviewed known-failure set for the exact package/evidence digest; both
  missing and additional findings fail.
- `release` fails on every error and every unwaived warning. Errors are never
  waivable. A warning waiver is valid only when it names an Issue, rationale,
  owner, affected actions/frames and a non-expired date.

Static package/source checks and supplemental runtime evidence share the same
finding model. Missing required evidence fails closed. Action semantics
(squash/stretch, airborne root movement, support phases and disconnected
components) are reviewed data, not implicit code exceptions.

## Consequences

Known defective content can remain reproducibly testable in baseline mode
without being mistaken for release-ready content. Release decisions become
byte-comparable and warning escape paths are explicit and time-bounded.
Callers producing runtime evidence must conform to the supplemental schema.
Threshold or baseline changes require reviewed source changes and fresh
content-matched evidence.

The report and supplemental evidence are test/release contracts only; this ADR
does not add `.catpet` metadata, modify runtime behavior or repair production
artwork.
