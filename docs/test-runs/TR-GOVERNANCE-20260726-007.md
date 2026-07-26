# TR-GOVERNANCE-20260726-007 — Second B2 staged-governance failure

- Status: fail
- Date: 2026-07-26T14:51:00Z
- Content-SHA256: efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a
- Commit/Tree: base `f829cc2b05a582e5e45b15e6a6d09932fcd66999`; revised staged B2 checkpoint
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-003

## Tested content

The staged B2 checkpoint after CHG-20260726-003 explicitly linked the
executed visual and governance TR IDs and included
TR-GOVERNANCE-20260726-006.

## Commands

```sh
git diff --cached --check
python3 Scripts/check_governance.py --staged --base main
```

## Passed

- Staging completed.
- `git diff --cached --check` reported no whitespace errors.

## Failed

Governance repeated that CHG-20260726-003 had no referenced passing TR
matching digest
`efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.

## Skipped

- Path and prohibited-artifact listings did not execute.
- No commit was created.

## Failure analysis

The CHG range expression exposed TR-VISUAL-20260726-007 as the referenced
final passing record, but its proposed metadata wrapped `Content-SHA256` in
Markdown backticks. The current checker compares the parsed metadata string
literally with the bare computed digest. The evidence digest was correct, but
its markup prevented freshness matching.

## Evidence

An explicit parse diagnostic confirmed:

- parsed TR value:
  `` `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a` ``;
- computed digest:
  `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.

## Retrospective

Use the checker's required bare digest form in the final referenced passing
TR, stage this failed run, and rerun under a new TR identity.
