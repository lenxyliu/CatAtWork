# TR-GOVERNANCE-20260727-001 — B3 closure staged verification

- Status: pass
- Date: 2026-07-27T03:18:00+08:00
- Content-SHA256: 0ba6eb93d724560e3499a0b2805084061a14c5022484f5982e8dff3976e069b8
- Commit/Tree: closure branch from accepted B3 merge
  `484fa7789d0a72423e8a1c89926e78d64de047b2`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026
- BC: BC-018, BC-020, BC-021, BC-024, BC-025, BC-029, BC-030
- CHG: CHG-20260727-001

## Tested content

The complete Markdown-only B3 publication closure: plan ledger, closure CHG
and accepted GitHub publication TR.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged \
  --base 484fa7789d0a72423e8a1c89926e78d64de047b2
python3 Scripts/check_governance.py digest
git diff --cached --name-only
git diff --cached --name-only | rg \
  '\.(png|jpg|jpeg|gif|tiff?|webp|heic|app|dmg|mov|mp4|p12|mobileprovision|pem|key)$|(^|/)(generated|qa|previews?|Build|\.build)(/|$)'
```

## Passed

- `git diff --cached --check` returned clean.
- Governance passed all three then-staged closure paths from exact accepted
  B3 base `484fa7789d0a72423e8a1c89926e78d64de047b2`.
- The governed product-content digest remained
  `0ba6eb93d724560e3499a0b2805084061a14c5022484f5982e8dff3976e069b8`.
- The prohibited artifact query returned zero paths.
- A final rerun including this TR itself passed all four closure paths.

## Failed

None.

## Skipped

Product Python, Swift, package and B2 oracle suites were not repeated because
the closure modifies only Markdown publication evidence and the plan. Their
accepted exact-head results remain TR-ASSET-20260726-016 through 019 and
hosted PR #28.

No production raster, B4 work, release, tag or GitHub Release was attempted.

## Failure analysis

None.

## Evidence

The exact four-path committed diff reconstructs the closure scope. Hosted PR
checks will independently repeat governance/Swift before closure acceptance.

## Retrospective

Publish the closure through its own reviewed squash PR, align local
`main`/`origin/main`, then hand off B4 as a new Local task without starting it.
