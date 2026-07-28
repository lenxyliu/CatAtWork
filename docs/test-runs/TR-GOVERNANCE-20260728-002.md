# TR-GOVERNANCE-20260728-002 — Foundation staged verification

- Status: pass
- Date: 2026-07-28T03:59:00Z
- Content-SHA256: 5e658733869e6fc0a0ba4e0a17b9cba9a616702479e94ee8cd61ea5795719077
- Commit/Tree: complete staged foundation delta from
  `main@36b033b28677403821e6ccefb96838b3f58c140f`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026
- BC: BC-018, BC-019, BC-020, BC-021, BC-024, BC-025, BC-029
- CHG: CHG-20260727-002

## Tested content

The complete B4 foundation branch delta: governed foundation references,
deterministic build/validation/QA tools, exactly 216 LFS source frames in nine
scoped actions, immutable TR evidence, Issue register and plan ledger.

## Commands

```sh
git reset --soft main
git diff --cached --check
python3 Scripts/check_governance.py --staged
python3 Scripts/check_governance.py digest
git diff --cached --name-only
```

The soft reset changed only the unpublished local branch history and index; it
preserved the complete working tree and collapsed the pre-change CHG checkpoint
with its implementation for the staged-only hook.

## Passed

- `git diff --cached --check` returned clean.
- The corrected staged governance run passed all 245 then-staged paths from
  exact base `36b033b28677403821e6ccefb96838b3f58c140f`.
- The governed product-content digest matched
  `5e658733869e6fc0a0ba4e0a17b9cba9a616702479e94ee8cd61ea5795719077`.
- A final rerun including this TR itself passed all 246 staged paths.

## Failed

None in this execution. TR-GOVERNANCE-20260728-001 preserves the rejected
split-commit attempt.

## Skipped

Hosted governance/Swift, PR review and squash merge remain publication steps.
Interaction, physical, integration, B5–B8 and release work were not started.

## Failure analysis

None.

## Evidence

The complete staged diff and passing hook output reconstruct this verification.
All 216 raster entries are LFS pointers in the index; no generated QA artifact,
atlas, application, DMG, credential or unscoped production frame is staged.

## Retrospective

The corrected history preserves the required sequencing—CHG created before
artwork edits—while presenting the complete governed slice to the staged-only
hook as one auditable branch delta.
