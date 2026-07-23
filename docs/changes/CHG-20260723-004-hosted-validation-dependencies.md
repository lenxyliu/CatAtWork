# CHG-20260723-004 — Provision hosted image-validation dependencies

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-009
- BC: BC-012
- ADR: ADR-0006
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-002, TR-CI-20260723-003, TR-CI-20260723-004, TR-CI-20260723-005

## Purpose

Make hosted package/asset validation install and report its Python/Pillow
environment instead of relying on developer-machine state.

## Before: badcase and risk

PR run `29984822374` passed toolchain identity, Swift build, all 36 tests and
core typecheck, then failed importing `PIL`. The dependency was absent from
the workflow and repository.

## Design impact

The test/release strategy now defines Python 3.13 and the pinned validation
requirements file as part of the hosted validation contract. ADR-0006 records
the dependency boundary.

## Changes

- Add `Scripts/requirements-validation.txt` with Pillow 12.3.0.
- Provision Python 3.13 through `actions/setup-python@v6`.
- Cache and install the declared requirements before validation.
- Log Python and Pillow versions in the toolchain identity step.

## Compatibility

No application runtime dependency is added. Pillow is installed only in the
CI validation environment. The hosted job requires access to the official
Python distribution cache and PyPI.

## Test evidence

TR-CI-20260723-002 records local validation with the developer environment
and the final governed digest. Hosted Python 3.13/Pillow 12.3.0 verification
is recorded by TR-CI-20260723-004.
TR-CI-20260723-003 refreshes local high-frame, source and Swift evidence after
the governance checker changed.

## Rollback

Before merge, close the branch and retain run `29984822374`. After merge,
replace rather than remove the declared dependency environment through a new
ADR/CHG if setup-python or Pillow must change.

## Revision log

- 2026-07-23: opened after hosted Pillow import failure; rerun pending.
- 2026-07-23: linked fresh TR-CI-20260723-003 without overwriting the earlier
  dependency-resolution execution.
- 2026-07-23: run `29985577013` installed the exact dependency set and passed
  hosted high-frame validation; ISSUE-009 is verified fixed.
- 2026-07-23: linked final-head TR-CI-20260723-005 after the main-push
  workflow changed.
