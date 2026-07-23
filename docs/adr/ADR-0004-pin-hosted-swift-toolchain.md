# ADR-0004 — Pin the hosted Swift toolchain

- Status: accepted
- Date: 2026-07-23
- CHG: CHG-20260723-002
- ISSUE: ISSUE-007

## Context

The first clean-baseline Actions run used the default toolchain on
`macos-14`. It provided Swift 5.10 while the package declares Swift tools 6.0,
so the authoritative build failed before compiling. A floating runner default
also makes later results difficult to reproduce.

## Decision

Run the Swift job on `macos-15` and set
`DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`. Print the
Xcode and Swift versions before build/test validation. Treat any later runner
or Xcode selection change as a strategic release-policy change requiring new
evidence.

## Consequences

The job uses a compiler new enough for the manifest and records its identity.
The workflow depends on Xcode 16.4 remaining available on the supported
`macos-15` image; if GitHub removes it, a new ADR/CHG must select and validate
the replacement rather than silently following a different default.
