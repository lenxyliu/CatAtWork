# TR-GOVERNANCE-20260726-013 — Initial B3 staged-governance failure

- Status: fail
- Date: 2026-07-26T18:58:00Z
- Content-SHA256: 0ba6eb93d724560e3499a0b2805084061a14c5022484f5982e8dff3976e069b8
- Commit/Tree: staged `codex/canonical-pet-asset-contract` candidate from
  `main@b0efc0e91f9ac7142c4517b4ee295215294f7907`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026
- BC: BC-018, BC-020, BC-021, BC-024, BC-025, BC-029, BC-030
- CHG: CHG-20260726-005

## Tested content

The first complete staged B3 implementation/evidence scope before commit.

## Commands

```sh
python3 Scripts/check_governance.py --staged
git diff --cached --check
git diff --cached --name-only
```

## Passed

- `git diff --cached --check` returned clean.
- The staged scope contained no raster, generated QA, app or DMG path.

## Failed

Governance rejected the staged records:

- TR-ASSET-20260726-019 omitted required `Xcode` and `Swift` metadata.
- The CHG had no machine-recognized passing TR for final digest
  `0ba6eb93d724560e3499a0b2805084061a14c5022484f5982e8dff3976e069b8`.

## Skipped

No commit, push, PR, production asset operation or B4 work occurred after the
failure.

## Failure analysis

The B3 TR files wrapped `Content-SHA256` values in Markdown backticks, while
the governance parser compares the raw metadata value to the 64-character
digest. The oracle record also lacked the repository-required toolchain
fields. This was an evidence-metadata defect, not a product/test failure.

## Evidence

The exact checker diagnostics are preserved in the B3 task terminal and in
the Failed section above.

## Retrospective

Normalize every B3 `Content-SHA256` metadata value, add the missing toolchain
fields and rerun staged governance into a new immutable TR.
