# TR-GOVERNANCE-20260726-014 — Recovered B3 staged verification

- Status: pass
- Date: 2026-07-26T19:01:00Z
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

The corrected complete B3 implementation, design, governance and immutable
test-evidence scope after TR-GOVERNANCE-20260726-013.

## Commands

```sh
python3 Scripts/check_governance.py --staged
git diff --cached --check
python3 Scripts/check_governance.py digest
git diff --cached --name-only
```

## Passed

- Governance passed for all 39 staged paths.
- `git diff --cached --check` returned clean.
- The governed-content digest exactly matched
  `0ba6eb93d724560e3499a0b2805084061a14c5022484f5982e8dff3976e069b8`.
- The staged path list contained no production raster, generated QA artifact,
  app, DMG, archive, credential or signing material.

## Failed

None.

## Skipped

No push, PR, hosted check, merge, release or B4 work was performed by this
local staged verification.

## Failure analysis

The metadata defect from TR-GOVERNANCE-20260726-013 is corrected. No governed
product file changed between the failed and passing governance executions.

## Evidence

The exact 39-path staged list and checker output are preserved in the B3 task
terminal; the path set is also reconstructible from the eventual commit
against its exact base.

## Retrospective

The candidate is locally publication-ready but is not accepted until the
exact committed PR head receives hosted governance/Swift and procedural
review.
