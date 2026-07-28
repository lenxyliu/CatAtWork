# TR-GOVERNANCE-20260728-001 — Split foundation commit rejected

- Status: fail
- Date: 2026-07-28T03:57:17Z
- Content-SHA256: 5e658733869e6fc0a0ba4e0a17b9cba9a616702479e94ee8cd61ea5795719077
- Commit/Tree: staged production delta on
  `codex/default-pet-visual-foundation@f36ed5c7356e81bb686ac361e707e2eaa50974ac`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-015, ISSUE-016, ISSUE-017, ISSUE-018, ISSUE-021, ISSUE-022, ISSUE-026
- BC: BC-018, BC-019, BC-020, BC-021, BC-024, BC-025, BC-029
- CHG: CHG-20260727-002

## Tested content

The staged 239-path production delta after the foundation contract and
CHG-20260727-002 had already been committed in the preceding unpublished local
checkpoint.

## Commands

```sh
git commit -m "Rebuild default pet foundation actions"
```

The governed pre-commit hook ran:

```sh
python3 Scripts/check_governance.py --staged
```

## Passed

The hook executed and prevented creation of a non-conforming commit.

## Failed

The staged-only comparison reported:

```text
Governance check failed:
- governed content changed without a new CHG record
```

The commit returned exit status 1 and no commit was created.

## Skipped

Push, PR creation and all later publication steps were not attempted.

## Failure analysis

CHG-20260727-002 was correctly created before production changes, but it was
added in the preceding unpublished local checkpoint. The staged-only hook
therefore saw the CHG as modified rather than added. The safe correction is to
collapse the two unpublished local checkpoints into one branch commit from the
unchanged `main` base so the complete branch delta contains the new CHG.

## Evidence

The exact hook output is preserved above. The rejected command did not change
HEAD, which remained
`f36ed5c7356e81bb686ac361e707e2eaa50974ac`.

## Retrospective

When a governed change uses a staged-only hook, keep the pre-change CHG and
the implementation in one unpublished commit even though the CHG file must
exist in the worktree before implementation begins.
