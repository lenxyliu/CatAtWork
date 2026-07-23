# ADR-0003 — Git LFS for current assets, Releases for prehistory

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-001
- ISSUE: ISSUE-005

## Context

Current runtime artwork benefits from normal source review, while generated drafts, historical snapshots, and DMGs are large immutable evidence that would permanently inflate Git/LFS history.

## Decision

Track only current production raster assets through Git LFS. Package generated drafts, QA previews, nine recovered Assets states, and historical DMGs as immutable attachments on private Release `prehistory-2026-07-23`. Keep small manifests and restoration instructions in Git.

## Consequences

Normal clones remain small and current images remain versioned. Restoring prehistory requires Release access and checksum verification. Git LFS must be installed before staging production images.

