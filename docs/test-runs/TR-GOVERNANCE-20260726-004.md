# TR-GOVERNANCE-20260726-004 — Historic-digest replay helper import failure

- Status: fail
- Date: 2026-07-26T14:46:10Z
- Content-SHA256: `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`
- Commit/Tree: base `f829cc2b05a582e5e45b15e6a6d09932fcd66999`; proposed B2 worktree
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-003

## Tested content

An in-memory helper intended to reconstruct the governed-content digest that
preceded the final workflow-only refinement. No repository file was to be
changed.

## Commands

Run `python3 Scripts/check_governance.py digest`, then execute an inline Python
helper that imports `Scripts/check_governance.py`, substitutes the prior
workflow text in memory and hashes the governed files.

## Passed

- The current digest command returned
  `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.

## Failed

The replay helper failed while defining the `Change` dataclass with
`AttributeError: 'NoneType' object has no attribute '__dict__'`.

## Skipped

- The historic digest was not produced by this invocation.
- No repository or temporary file was written.

## Failure analysis

The `importlib` module object was executed without first being registered in
`sys.modules`; Python 3.9 dataclass annotation resolution expected that
registration.

## Evidence

The terminal retained the traceback at
`Scripts/check_governance.py:104` and the current digest printed before it.

## Retrospective

The retry registers the module before execution and has its own immutable TR.
