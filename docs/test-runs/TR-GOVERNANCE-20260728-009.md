# TR-GOVERNANCE-20260728-009 — Foundation color staged metadata failure

- Status: fail
- Date: 2026-07-28T14:50:00Z
- Content-SHA256: b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce
- Commit/Tree: staged `codex/default-pet-visual-foundation-color-correction` based on `4011d2d8c8fc4559ee1da911a8b9b29fd720d16f`
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-016, ISSUE-026; GitHub #10, #21
- BC: BC-019, BC-029
- CHG: CHG-20260728-001

## Tested content

The first exact staged 234-path correction diff after local asset acceptance.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged
```

## Passed

`git diff --cached --check` passed. All intended paths were staged and
`git lfs status` identified every scoped PNG as an LFS object.

## Failed

Governance reported that CHG-20260728-001 had no referenced passing TR for
digest
`b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce`.

## Skipped

Commit, push, Issue updates, PR publication, merge and all out-of-scope work.

## Failure analysis

The CHG's `TR` metadata value was wrapped across continuation lines. The
governance metadata parser reads only the first `- TR:` line, so it saw the
older failed TR identifiers but not the content-matched passing
TR-ASSET-20260728-023 on the continuation line. This is a record-format
failure, not a product or evidence-digest mismatch.

## Evidence

The failed command output is retained by this record. The corrected CHG keeps
all TR identifiers on one metadata line before the independent rerun.

## Retrospective

Required governance metadata lists must remain on one physical Markdown line
until the parser supports continuations.
