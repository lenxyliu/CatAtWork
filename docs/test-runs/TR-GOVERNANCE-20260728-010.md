# TR-GOVERNANCE-20260728-010 — Foundation color failed-TR schema failure

- Status: fail
- Date: 2026-07-28T14:55:00Z
- Content-SHA256: b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce
- Commit/Tree: staged `codex/default-pet-visual-foundation-color-correction` based on `4011d2d8c8fc4559ee1da911a8b9b29fd720d16f`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016, ISSUE-026; GitHub #10, #21
- BC: BC-019, BC-029
- CHG: CHG-20260728-001

## Tested content

The second exact staged correction diff after placing all CHG TR identifiers
on one metadata line.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged
```

## Passed

The corrected CHG metadata allowed governance to locate the
content-matched passing TR-ASSET-20260728-023.

## Failed

Governance then found that the immutable rejection evidence
TR-ASSET-20260728-021 lacked the required `## Commands` heading and `Xcode`
and `Swift` metadata.

## Skipped

Commit, push, Issue updates, PR publication, merge and all out-of-scope work.

## Failure analysis

TR-ASSET-20260728-021 was created during the native rejection pause with the
failure outcome and hashes intact but without the full governed TR schema.
Adding the missing environment metadata and command summary does not alter or
erase its failed result.

## Evidence

This record preserves the second staged governance output. The rejection TR
continues to retain the same user decision, content digest, manifest, report
hashes and failed detail analysis.

## Retrospective

Failed native records require the same complete schema as passing automated
records before publication.
