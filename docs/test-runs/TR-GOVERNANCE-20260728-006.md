# TR-GOVERNANCE-20260728-006 — Interaction checkpoint multiline-reference failure

- Status: fail-preserved
- Date: 2026-07-28T10:25:00Z
- Content-SHA256: `a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`
- Commit/Tree: staged `codex/default-pet-visual-interaction`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016
- BC: BC-019
- CHG: CHG-20260727-004

## Tested content

The same staged interaction checkpoint with complete metadata on the passing
TR and both earlier governance-failure records.

## Commands

```sh
/usr/bin/python3 Scripts/check_governance.py --staged
```

## Passed

The checker resolved the same stable governed-content digest.

## Failed

The CHG's TR metadata wrapped the explicit passing TR onto a continuation
line. The governance metadata parser intentionally reads only the value on the
`- TR:` line, so the passing identity still was not referenced.

## Skipped

No production raster, package, Swift suite, PR or hosted check was involved.

## Failure analysis

This was a Markdown metadata serialization error. It did not change governed
code or invalidate candidate-4 measurements.

## Evidence

The only checker error was no referenced passing TR for digest
`a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`.

## Retrospective

Keep every machine-readable metadata value, especially the passing TR
identity, on its own complete metadata line.
