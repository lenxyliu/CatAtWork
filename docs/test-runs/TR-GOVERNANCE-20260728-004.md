# TR-GOVERNANCE-20260728-004 — Interaction checkpoint freshness failure

- Status: fail-preserved
- Date: 2026-07-28T10:20:00Z
- Content-SHA256: `a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`
- Commit/Tree: staged `codex/default-pet-visual-interaction`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016
- BC: BC-019
- CHG: CHG-20260727-004

## Tested content

The exact staged interaction contract, deterministic assembly/validation/QA
scripts, tests and blocking governance records.

## Commands

```sh
/usr/bin/python3 Scripts/check_governance.py --staged
```

## Passed

The checker resolved the staged governed-content digest shown above.

## Failed

The command failed because CHG-20260727-004 did not yet reference a passing TR
whose Content-SHA256 matched the current digest.

## Skipped

No production raster, package, Swift suite, PR or hosted check was involved.

## Failure analysis

This is the intended fail-closed freshness behavior. The isolated candidate-4
validation existed outside the repository, but no content-matched durable
checkpoint TR had yet bound the newly staged scripts and contract.

## Evidence

The exact checker message was:
`no referenced passing TR matches current digest
a1f6928fd634491bf016a3b69e0c196b0e17a10caadd806f19a1b216a67b9744`.

## Retrospective

Create a new passing checkpoint TR without modifying or erasing this failure,
then rerun governance under a new execution.
