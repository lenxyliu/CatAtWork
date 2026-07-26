# TR-GOVERNANCE-20260726-010 — B2 publication final-head verification

- Status: pass
- Date: 2026-07-26T15:04:14Z
- Content-SHA256: efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a
- Commit/Tree: final B2 head `443023ec738c4b449416dcb01e38355a789b9b2e`; base `f829cc2b05a582e5e45b15e6a6d09932fcd66999`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-004

## Tested content

The unchanged 42-path B2 final head immediately before push and again during
the final publication-scope review.

## Commands

```sh
python3 -B -m unittest discover -s Scripts/tests -p 'test_*.py'
git diff --check main...HEAD
python3 Scripts/check_governance.py --base main
git diff --name-only main...HEAD
git diff --name-only main...HEAD -- \
  '*.png' '*.jpg' '*.jpeg' '*.gif' '*.tiff' '*.webp' \
  '*.app' '*.dmg' '*.mov' '*.mp4' '*.p12' '*.mobileprovision' '*.pem' '*.key'
python3 -m json.tool Schemas/visual-qa-report-v1.schema.json >/dev/null
for file in Tests/Fixtures/VisualQA/*.json \
  Tests/Fixtures/VisualQA/negative/*.json; do
  python3 -m json.tool "$file" >/dev/null || exit 1
done
```

Runtime/package path filters also checked `Sources/CatAtWork`,
`Sources/CatAtWorkCore`, `Package.swift` and `Package.resolved`.

## Passed

- 22/22 Python tests passed in 0.111 seconds.
- `git diff --check main...HEAD` passed.
- Governance passed for all 42 changed paths.
- The governed-content digest remained
  `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.
- Every schema, contract, supplemental and clean/negative fixture JSON parsed.
- Prohibited-artifact and runtime/package path filters returned empty.
- The worktree was clean before push and final review.

## Failed

None.

## Skipped

- Full package baseline/release and fresh Swift reruns were not repeated
  locally because content-matched TR-VISUAL-20260726-004..007 already covered
  the same governed digest and hosted `swift` repeated them on the final head.
- No native-device acceptance was required for the test/release-policy-only
  B2 change.

## Failure analysis

None.

## Evidence

The terminal captured exact tool versions, digest, test count, governance path
count and empty filters.

## Retrospective

The publication task did not modify the reviewed B2 head before its hosted
checks and squash merge.
