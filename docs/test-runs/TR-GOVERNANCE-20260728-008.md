# TR-GOVERNANCE-20260728-008 — Blocked interaction checkpoint governance

- Status: pass
- Date: 2026-07-28T10:29:00Z
- Content-SHA256: a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744
- Commit/Tree: staged `codex/default-pet-visual-interaction`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-021,
  ISSUE-022, ISSUE-026
- BC: BC-018, BC-019, BC-020, BC-021, BC-024, BC-025, BC-029
- CHG: CHG-20260727-004

## Tested content

The exact staged blocked interaction checkpoint: contract, three deterministic
asset scripts, four Python tests, CHG, Issue/BC/plan updates and immutable
candidate/failure records.

## Commands

```sh
/usr/bin/python3 Scripts/check_governance.py --staged
```

## Passed

Governance passed all 31 staged paths at governed-content digest
`a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`.
The CHG references a passing content-matched TR and every new immutable record
has the required structure.

## Failed

None in this execution. TR-GOVERNANCE-20260728-004..007 preserve the four
preceding fail-closed executions.

## Skipped

No production raster install/LFS stage, fresh Swift, final package, PR, hosted
check, review or merge was performed because native color acceptance is
blocked.

## Failure analysis

Not applicable to this passing execution. The product-level color blocker
remains TR-ASSET-20260728-017 and is not waived by governance success.

## Evidence

- Changed paths: 31
- Governed-content digest:
  `a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`
- Exact output: `Governance check passed for 31 changed paths.`

## Retrospective

A publishable interaction PR still requires the separate foundation
color-correction prerequisite and the skipped production/native/Swift/hosted
exit gates.
