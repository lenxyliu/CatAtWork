# TR-GOVERNANCE-20260728-005 — Interaction checkpoint metadata failure

- Status: fail-preserved
- Date: 2026-07-28T10:23:00Z
- Content-SHA256: `a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`
- Commit/Tree: staged `codex/default-pet-visual-interaction`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016
- BC: BC-019
- CHG: CHG-20260727-004

## Tested content

The staged interaction checkpoint after adding the first freshness-failure
record and a passing content-matched TR.

## Commands

```sh
/usr/bin/python3 Scripts/check_governance.py --staged
```

## Passed

The checker again resolved the stable governed-content digest shown above.

## Failed

The newly referenced TR-GOVERNANCE-20260728-004 omitted required
System/Xcode/Swift metadata, and the CHG metadata used a numeric range that did
not parse as an explicit reference to TR-ASSET-20260728-018.

## Skipped

No production raster, package, Swift suite, PR or hosted check was involved.

## Failure analysis

The evidence content was present, but its machine-readable metadata was
incomplete. This is a governance-record construction failure, not a passing
product verification.

## Evidence

The checker reported the three missing metadata fields and no referenced
passing TR for digest
`a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`.

## Retrospective

Use explicit TR identities in CHG metadata and include the full required
environment metadata on every referenced TR.
