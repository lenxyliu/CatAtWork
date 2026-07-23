# CHG-20260723-001 — Repository recovery and governance baseline

- Status: in-progress
- Change-Type: governance
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-005, ISSUE-006
- BC: BC-008, BC-009
- ADR: ADR-0001, ADR-0002, ADR-0003
- Design: SYSTEM-ARCHITECTURE, ASSET-PIPELINE, TEST-AND-RELEASE
- TR: TR-BASELINE-20260723-001, TR-BASELINE-20260723-002, TR-GOVERNANCE-20260723-001, TR-RECOVERY-20260723-001, TR-BASELINE-20260723-003

## Purpose

Preserve binary prehistory, create a clean and small source baseline, and make every later non-trivial change traceable from problem and design through exact test evidence.

## Before: badcase and risk

The old unborn Git object database exceeds 2 GiB and contains the only copies of multiple Assets trees. `.build`/`Build` mix disposable output with historical DMGs. Mutable audit files and tests without content digests allow prior evidence to be overwritten or reused after changes.

## Design impact

Adds mandatory repository workflow, immutable evidence types, Git LFS/Release asset boundaries, protected-main strategy and automated governance checks. It does not claim an application behavior change.

## Changes

- Freeze old `.git` outside the workspace and export all unique Assets tree snapshots.
- Add LFS attributes and ignore reproducible/generated output.
- Add agent/contributor rules, design documents, accepted ADRs, stable issues/badcases, templates, recovery manifest, checker, hooks and CI.
- Install the checksum-verified Git LFS v3.7.0 arm64 binary at `/Users/oops/.local/bin/git-lfs`; repository-local filter setup waits for clean Git initialization.
- Prepare migration to a fresh `main` after local and remote archive verification.

## Compatibility

The application source/package contract is unchanged in this CHG. Git LFS becomes required for a full source checkout containing production raster assets. Private Release access is required for prehistory restoration.

## Test evidence

Local governance, 36-test Swift baseline, build/typecheck/package/import checks and build 8 DMG validation pass in `TR-GOVERNANCE-20260723-001` and `TR-BASELINE-20260723-002`. The initial sandbox failure is preserved as `TR-BASELINE-20260723-001`. Local recovery integrity is `partial` in `TR-RECOVERY-20260723-001`; GitHub upload/download verification remains required.

## Rollback

Before the clean baseline is pushed, remove only the newly added governance files. Never delete the external frozen Git backup or exported archives. After merge, supersede this policy through a new ADR/CHG; do not rewrite this record.

## Revision log

- 2026-07-23: opened; local old-Git backup and nine Assets exports completed.
- 2026-07-23: local governance/source/package/DMG baseline verified; remote round trip pending.
- 2026-07-23: Git LFS v3.7.0 downloaded from the official release, official ZIP hash matched, and installed binary matched the extracted source hash.
- 2026-07-23: private empty repository `lenxyliu/CatAtWork` created; final hook/governance digest retested before staging.
