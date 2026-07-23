# CHG-20260723-002 — Align hosted CI with Swift tools 6.0

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-007
- BC: BC-010
- ADR: ADR-0004
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-001, TR-CI-20260723-003, TR-CI-20260723-004

## Purpose

Make the authoritative hosted build use a declared Swift 6-capable toolchain
and expose the exact Xcode/Swift identity in every CI result.

## Before: badcase and risk

Baseline Actions run `29977724140` selected Swift 5.10 on `macos-14` and
failed before compilation because the package requires Swift tools 6.0.
Leaving the default unpinned can recreate the mismatch when runner defaults
change.

## Design impact

The test/release strategy now defines a hosted toolchain contract:
`macos-15` plus Xcode 16.4 selected through `DEVELOPER_DIR`, with identity
logged before build. ADR-0004 records why this is a release-policy decision.

## Changes

- Change the Swift job runner from `macos-14` to `macos-15`.
- Select `/Applications/Xcode_16.4.app/Contents/Developer`.
- Log `xcodebuild -version` and `swift --version` before compilation.
- Preserve the existing build, 36-test and package/source validation steps.

## Compatibility

No application source, package schema or production asset changes. The hosted
job now requires the GitHub `macos-15` image to provide Xcode 16.4 at its
documented path.

## Test evidence

TR-CI-20260723-001 records local governance fixtures, Swift build/tests and
workflow policy checks against the final governed digest. Hosted Actions
verification is recorded by TR-CI-20260723-004.
TR-CI-20260723-003 refreshes that local evidence after the governance
lifecycle correction changed executable scripts.

## Rollback

Before merge, close the branch and retain failed run `29977724140` as
evidence. After merge, do not silently return to `macos-14`; supersede this
decision with a new ADR/CHG that selects another Swift 6-capable hosted
toolchain.

## Revision log

- 2026-07-23: opened after baseline run `29977724140` exposed the Swift
  5.10/6.0 mismatch; hosted verification pending.
- 2026-07-23: linked fresh TR-CI-20260723-003 after the PR governance checker
  changed; the earlier execution remains preserved.
- 2026-07-23: run `29985577013` passed the complete hosted Swift job;
  ISSUE-007 is verified fixed.
