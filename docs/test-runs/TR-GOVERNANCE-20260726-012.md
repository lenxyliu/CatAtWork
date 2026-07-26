# TR-GOVERNANCE-20260726-012 — B2 closure staged verification

- Status: pass
- Date: 2026-07-26T15:16:00Z
- Content-SHA256: efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a
- Commit/Tree: closure branch from accepted B2 merge `72d2154afbe590654ce5c21be7363d9c67ac267f`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-004

## Tested content

The complete Markdown-only B2 publication closure: CHG, ISSUE/BC lifecycle
status, plan ledger and all new failed/passing publication/governance TRs.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged --base main
git diff --cached --name-only
git diff --cached --name-only -- \
  '*.png' '*.jpg' '*.jpeg' '*.gif' '*.tiff' '*.webp' \
  '*.app' '*.dmg' '*.mov' '*.mp4' '*.p12' '*.mobileprovision' '*.pem' '*.key'
```

## Passed

- Staged whitespace and governance checks passed against exact
  `main@72d2154afbe590654ce5c21be7363d9c67ac267f`.
- The governed-content digest remained
  `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.
- Every changed path was a Markdown governance/evidence path.
- The prohibited artifact filter returned no path.

## Failed

None.

## Skipped

- Product Python/Swift/package tests were not rerun because the closure does
  not change governed product, workflow, schema, fixture or runtime content.
- No production raster exists in the closure diff, so no LFS staging check was
  applicable.

## Failure analysis

None.

## Evidence

The terminal path list and empty prohibited-artifact query are the closure
scope evidence; hosted PR checks independently repeat governance and Swift.

## Retrospective

Publish this exact closure commit through its own reviewed squash PR without
beginning B3.
