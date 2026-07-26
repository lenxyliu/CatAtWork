# TR-GOVERNANCE-20260726-001 — B1 publication-closure verification

- Status: pass
- Date: 2026-07-26T10:37:23Z
- Content-SHA256: `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`
- Commit/Tree: base `054c05f4450a162b981d980456abdc443521a530`; proposed B1 publication-closure records
- System: macOS 26.5.2 (25F84), Apple M4 Pro
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015 through ISSUE-026; GitHub #15
- BC: BC-018 through BC-029
- CHG: CHG-20260726-001

## Tested content

The post-merge B1 closure diff: one plan-ledger update, one CHG and two TR
records. All paths are Markdown; the accepted B1 product and asset content is
unchanged.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged --base main
python3 Scripts/check_governance.py --base main
git diff --name-only main...HEAD
git diff --name-only main...HEAD -- '*.png' '*.jpg' '*.jpeg' '*.gif' '*.tiff' '*.webp' '*.app' '*.dmg' '*.mov' '*.mp4' '*.p12' '*.mobileprovision' '*.pem' '*.key'
```

## Passed

- `git diff --cached --check` reported no whitespace errors.
- Staged governance passed for all four closure paths.
- The committed `--base main` governance form passed for the same four paths.
- The final path list contains Markdown only.
- The raster, application, DMG, recording and credential-key extension filter
  returned no paths.
- The governed-content digest remained
  `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`.

## Failed

None.

## Skipped

- Product, package and visual tests were not repeated because the closure diff
  changes no governed product, test, configuration, schema or asset content.
- B2 gates and implementation were not started.

## Failure analysis

None.

## Evidence

The four exact changed paths are this TR, TR-GITHUB-20260726-001,
CHG-20260726-001 and the visual-remediation plan. The clean command output and
final Git state are summarized in this immutable record.

## Retrospective

Recording the merge SHA after the B1 squash requires a small follow-up PR;
direct mutation of `main` is intentionally avoided.
