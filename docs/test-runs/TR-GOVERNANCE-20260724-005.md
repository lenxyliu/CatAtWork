# TR-GOVERNANCE-20260724-005 — B1 final repository verification

- Status: pass
- Date: 2026-07-24T09:08:29Z
- Content-SHA256: `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`
- Commit/Tree: base `0ca2b518d5a079ace1ef1e6d9a6892a5259b080e`; proposed staged B1 records
- System: macOS 26.5.2 (25F84), Apple M4 Pro
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015 through ISSUE-026
- BC: BC-018 through BC-029
- CHG: CHG-20260724-003

## Tested content

All intended B1 durable Markdown changes, with generated QA files, temporary
builds/probes and production content excluded from the index.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged --base main
python3 Scripts/check_governance.py --base main
git diff --cached --name-only
git diff --cached --name-only -- '*.png' '*.jpg' '*.jpeg' '*.gif' '*.tiff' '*.webp' '*.app' '*.dmg'
```

## Passed

- `git diff --cached --check`: no whitespace errors.
- Staged governance: passed for 28 changed paths.
- Required pre-commit form `python3 Scripts/check_governance.py --base main`:
  exited 0.
- The staged list contains Markdown only.
- The binary/raster/application/DMG filter returned no paths.

## Failed

None recorded yet.

## Skipped

- Product tests were not repeated here; their exact runs are
  TR-VISUAL-20260724-003 through TR-VISUAL-20260724-011.

## Failure analysis

None.

## Evidence

The staged path list is the 28 durable files named by CHG-20260724-003. The
governed-content digest remains
`59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`;
no product or production asset content changed.

## Retrospective

The meaningful uncommitted check uses `--staged`; the required `--base main`
form is repeated again after the commit so it evaluates the committed branch
diff.
