# TR-GOVERNANCE-20260726-003 — Final B1 evidence-publication verification

- Status: pass
- Date: 2026-07-26T11:20:46Z
- Content-SHA256: `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`
- Commit/Tree: base `eb988253689d4ea31c462f4ef6b76015a61a4630`; proposed final evidence records
- System: macOS 26.5.2 (25F84), Apple M4 Pro
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015 through ISSUE-026; GitHub #15
- BC: BC-018 through BC-029
- CHG: CHG-20260726-002

## Tested content

One plan-ledger update, CHG-20260726-002, the failed and successful final #15
comment TRs, and this final governance TR.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged --base main
git diff --check main...HEAD
python3 Scripts/check_governance.py --base main
git diff --name-only main...HEAD
git diff --name-only main...HEAD -- '*.png' '*.jpg' '*.jpeg' '*.gif' '*.tiff' '*.webp' '*.app' '*.dmg' '*.mov' '*.mp4' '*.p12' '*.mobileprovision' '*.pem' '*.key'
```

## Passed

- Staged and committed diff checks reported no whitespace errors.
- Staged and committed governance checks passed for all five paths.
- All five paths are Markdown and the prohibited artifact-extension filter
  returned no paths.
- The governed-content digest remained
  `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`.

## Failed

None.

## Skipped

- Product, package and visual tests were not repeated because no governed
  product, test, configuration, schema or asset content changed.
- B2 was not started.

## Failure analysis

None.

## Evidence

The five paths are the visual-remediation plan, CHG-20260726-002,
TR-GITHUB-20260726-004/005 and this TR.

## Retrospective

This bounded follow-up exists only to preserve the final failed publication
attempt and its successful retry; it adds no new visual conclusion.
