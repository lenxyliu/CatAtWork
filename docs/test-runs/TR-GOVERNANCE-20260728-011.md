# TR-GOVERNANCE-20260728-011 — Foundation color staged acceptance

- Status: pass
- Date: 2026-07-28T14:55:03Z
- Content-SHA256: b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce
- Commit/Tree: staged `codex/default-pet-visual-foundation-color-correction` based on `4011d2d8c8fc4559ee1da911a8b9b29fd720d16f`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016, ISSUE-026; GitHub #10, #21
- BC: BC-019, BC-029
- CHG: CHG-20260728-001

## Tested content

The exact 236-path staged color-correction diff after preserving both prior
governance failures and completing every referenced TR schema.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged
python3 Scripts/check_governance.py digest
git diff --cached --name-only
git lfs status
```

## Passed

- `git diff --cached --check` returned clean.
- Governance passed all 236 staged paths.
- The governed content digest matched
  `b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce`.
- All 216 scoped raster changes were staged as LFS objects.
- The staged artifact query contained no app, build, preview, recording,
  credential, DMG or release artifact.

## Failed

None. TR-GOVERNANCE-20260728-009 and
TR-GOVERNANCE-20260728-010 preserve the preceding metadata failures.

## Skipped

Hosted governance/Swift, review, merge and Issue publication remain pending.
Interaction, physical, integration, B5–B8 and release work remain untouched.

## Failure analysis

None. The staged tree passed after record-only schema corrections.

## Evidence

The staged index reconstructs the exact checked diff. The final rerun after
adding this passing record must include 237 paths and remain content-digest
identical.

## Retrospective

Run governance once more after adding its own passing TR so the published
index is exactly the index represented by the final result.
