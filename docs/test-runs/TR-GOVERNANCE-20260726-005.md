# TR-GOVERNANCE-20260726-005 — Historic-digest replay recovery

- Status: pass
- Date: 2026-07-26T14:46:24Z
- Content-SHA256: `efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`
- Commit/Tree: base `f829cc2b05a582e5e45b15e6a6d09932fcd66999`; proposed B2 worktree
- System: macOS 26.5.2 (25F84), Apple M4 Pro; Python 3.9.6
- Xcode: 26.6 (17F113)
- Swift: 6.3.3
- ISSUE: ISSUE-027
- BC: BC-030
- CHG: CHG-20260726-003

## Tested content

The same in-memory historic-digest reconstruction as
TR-GOVERNANCE-20260726-004, with correct `sys.modules` registration.

## Commands

Import the governance checker under a unique module name, register it in
`sys.modules`, iterate its governed file set, substitute only the prior
workflow-test routing in memory, and reproduce `content_digest` byte framing.

## Passed

- The helper completed without modifying any file.
- It reconstructed the exact pre-refinement digest:
  `d1c79513eb6a1f8e29eafd091cae162544e9ad0c43596bab7ff87899e4538d2d`.
- The digest supplies exact freshness identity for
  TR-VISUAL-20260726-002/003.

## Failed

None.

## Skipped

- No test result was changed or rerun by this helper.

## Failure analysis

None.

## Evidence

The terminal printed
`pre_workflow_final_digest d1c79513eb6a1f8e29eafd091cae162544e9ad0c43596bab7ff87899e4538d2d`.

## Retrospective

The final governed digest remains the independently printed
`efc7739785aa0dcbbf090f99f367c74250aec49160b11af68022d3925441298a`.
