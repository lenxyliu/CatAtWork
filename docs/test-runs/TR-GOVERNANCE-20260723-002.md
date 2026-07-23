# TR-GOVERNANCE-20260723-002 — Follow-up code lacked a new CHG

- Status: fail
- Date: 2026-07-23T17:52:10+08:00
- Content-SHA256: d3f054bfa9d2f3312bec525c09f52ab1dcef95c78bdfa24d6451ba6529421284
- Commit/Tree: staged follow-up to `1bb33d3` before CHG-20260723-013
- System: macOS 26.5.2 (25F84), arm64; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-003
- BC: BC-006
- CHG: CHG-20260723-013

## Tested content

The staged Metal actor-boundary correction, updated ISSUE/BC/CHG-012 records
and TR-IO-20260723-005/006 before an independent follow-up CHG existed.

## Commands

```sh
git commit -m "fix: wrap Metal device before actor transfer"
```

The repository pre-commit hook invoked:

```sh
python3 Scripts/check_governance.py --staged
```

## Passed

No commit was created and no staged content was lost.

## Failed

The governance checker rejected the staged code with:

```text
governed content changed without a new CHG record
```

## Skipped

Commit creation, push and hosted rerun did not occur.

## Failure analysis

CHG-20260723-012 already existed in the branch's HEAD, so updating it did not
count as adding a change record for the second non-trivial commit. The correct
response is a focused follow-up CHG for the CI compatibility fix, not bypassing
the local hook.

## Evidence

- Failed pre-commit output in the 2026-07-23 Codex task.
- Staged content remained intact after Git exited 1.

## Retrospective

One coherent PR can still contain multiple independently committed fixes. Each
non-trivial commit needs its own newly added CHG so a later squash preserves
why the follow-up happened and which failure caused it.
