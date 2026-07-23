# ADR-0002 — Recover evidence, then create a clean Git baseline

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-001
- ISSUE: ISSUE-005

## Context

The unborn repository contains more than 2 GiB of loose objects and Codex-internal snapshot refs. Destructive garbage collection risks deleting the only historical copies of action artwork.

## Decision

Freeze the full old `.git` outside the workspace, export every unique Assets tree, validate archives, then move the old `.git` out and initialize a new `main`. Do not mutate internal refs or attempt to preserve the bloated object graph as the product repository.

## Consequences

The clean repository has comprehensible history. Prehistory remains recoverable through the frozen backup and immutable archives, with checksums and restoration commands. Removal requires remote round-trip verification and explicit approval.

