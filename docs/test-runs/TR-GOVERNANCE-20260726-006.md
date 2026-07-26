# TR-GOVERNANCE-20260726-006 — Initial B2 staged-governance failure

- Status: fail
- Date: 2026-07-26T14:50:00Z
- Content-SHA256: `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`
- Commit/Tree: base `f829cc2b05a582e5e45b15e6a6d09932fcd66999`; first staged B2 checkpoint
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-003

## Tested content

The first staged implementation checkpoint: workflow, report schema, B2
validator, governed contracts/fixtures, ISSUE/BC/ADR/CHG/design and executed
TR records.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged --base main
```

The command chain would list staged and prohibited artifact paths only if
governance passed.

## Passed

- All intended paths staged successfully.
- `git diff --cached --check` reported no whitespace errors.

## Failed

Governance reported that CHG-20260726-003 did not reference a passing TR whose
`Content-SHA256` matched
`efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.

## Skipped

- Staged path listing and prohibited-artifact filtering did not execute
  because the `&&` command chain stopped at governance.
- No commit was created.

## Failure analysis

Passing final-digest TR-VISUAL-20260726-004 through 007 already existed, but
the CHG metadata and Test evidence still named only the red TR and a
placeholder for future runs. The evidence existed; the CHG linkage was
incomplete.

## Evidence

The one-line governance diagnostic named CHG-20260726-003 and the exact
missing digest.

## Retrospective

Link every executed B2 TR explicitly, stage the new failed-run record, and
rerun governance under a new TR identity.
