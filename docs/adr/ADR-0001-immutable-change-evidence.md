# ADR-0001 — Immutable design-to-release evidence

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-001
- ISSUE: ISSUE-006

## Context

Prior issue and completion files were repeatedly updated in place, so a later claim could replace the circumstances and test state of an earlier fix.

## Decision

Use stable ISSUE and BC identities, evolving design documents with append-only revision logs, immutable accepted ADRs, immutable-after-merge CHGs, immutable TRs (including failures), and one audit per candidate. Local hooks are advisory; GitHub Actions is authoritative.

## Consequences

Non-trivial work has documentation overhead, but a fix claim can be traced to its reproduction, decision, exact tested content and release evidence. Corrections supersede records instead of rewriting them.

