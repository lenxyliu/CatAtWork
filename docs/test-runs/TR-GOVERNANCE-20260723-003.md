# TR-GOVERNANCE-20260723-003 — Runtime CHG was missing a passing TR

- Status: fail
- Date: 2026-07-23T18:14:20+08:00
- Content-SHA256: d2e8973a854f220b79ce725c072244351f9b7513a7abfef4beeac4dca8178dbb
- Commit/Tree: staged `codex/runtime-controller-split` before final runtime TR
- System: macOS 26.5.2 (25F84), arm64; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-004
- BC: BC-007
- CHG: CHG-20260723-014

## Tested content

The staged runtime reducer, controller adapter and focused tests before the
passing content-matched test record was added.

## Commands

```sh
python3 Scripts/check_governance.py --staged
```

## Passed

- The staged diff contained the required new CHG, ADR, design revision, ISSUE,
  BC and implementation records.

## Failed

The local staged governance gate rejected the change because CHG-20260723-014
still had `TR: pending` and therefore no passing test record reference.

## Skipped

- Commit, push and hosted checks did not run from this rejected staged state.

## Failure analysis

The repository gate intentionally requires the change record to point at a
passing TR whose governed-content digest matches. The implementation tests had
passed, but the evidence link had not yet been finalized.

## Evidence

- Pre-commit/staged output from the 2026-07-23 Codex task.

## Retrospective

Finalize the immutable pass record and update CHG/ISSUE/BC references before
retrying the staged gate; never bypass it or erase this failed attempt.
