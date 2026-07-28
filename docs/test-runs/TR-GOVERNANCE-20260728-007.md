# TR-GOVERNANCE-20260728-007 — Interaction checkpoint digest-format failure

- Status: fail-preserved
- Date: 2026-07-28T10:27:00Z
- Content-SHA256: a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744
- Commit/Tree: staged `codex/default-pet-visual-interaction`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016
- BC: BC-019
- CHG: CHG-20260727-004

## Tested content

The same staged interaction checkpoint after placing the passing TR identity
on the CHG metadata line.

## Commands

```sh
/usr/bin/python3 Scripts/check_governance.py --staged
```

## Passed

The checker resolved the stable governed-content digest and the explicit
passing TR identity.

## Failed

The passing TR wrapped its Content-SHA256 value in Markdown code ticks. The
governance freshness comparison is intentionally exact, so the decorated
string did not equal the raw digest.

## Skipped

No production raster, package, Swift suite, PR or hosted check was involved.

## Failure analysis

This was a machine-readable digest-format error, not a content mismatch.

## Evidence

The checker reported no referenced passing TR for raw digest
`a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`;
direct metadata inspection showed the passing TR value included code ticks.

## Retrospective

Store raw digests without Markdown decoration in required metadata fields.
