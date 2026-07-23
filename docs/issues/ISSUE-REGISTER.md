# Issue register

The root `ISSUE-CLASSIFICATION.md` is a frozen pre-governance snapshot. Its rows have stable migrated IDs in `LEGACY-ISSUE-MAP.md`; later status is recorded here or in new immutable evidence, never by editing the snapshot.

| ID | Priority | Status | Summary | Badcase | Planned branch |
| --- | --- | --- | --- | --- | --- |
| ISSUE-001 | P1 | fixed | Priority reordering can invalidate pose transitions precomputed at enqueue | BC-001; TR-ACTION-20260723-001 | `codex/action-state-machine` |
| ISSUE-002 | P1 | fixed | `.catpet` capability/pose/next/scale/fallback contract is inconsistently applied | BC-002, BC-003, BC-004; TR-PACKAGE-20260723-002 | `codex/pet-package-contract` |
| ISSUE-003 | P1 | fixed | Import/image work can block the main thread; process pipes and texture loads are unsafe | BC-005, BC-006; TR-IO-20260723-006 | `codex/background-asset-io` |
| ISSUE-004 | P2 | open | Window controller duplicates runtime state and prevents focused App integration tests | BC-007 | `codex/runtime-controller-split` |
| ISSUE-005 | P0 | closed | Loose Git objects and build/history artifacts were preserved, remotely verified and cleaned | BC-008; TR-RECOVERY-20260723-002 | baseline |
| ISSUE-006 | P1 | fixed | Design, defect, badcase and test history can be overwritten or omitted | BC-009; TR-GOVERNANCE-20260723-001 | baseline |
| ISSUE-007 | P1 | fixed | Hosted CI selected Swift 5.10 for a Swift tools 6.0 package | BC-010; TR-CI-20260723-004 | `codex/ci-swift6-baseline` |
| ISSUE-008 | P0 | fixed | Governed dotfiles were silently omitted from test-evidence freshness digests | BC-011; TR-CI-20260723-001 | `codex/ci-swift6-baseline` |
| ISSUE-009 | P1 | fixed | Hosted asset validation depended on an undeclared Pillow installation | BC-012; TR-CI-20260723-004 | `codex/ci-swift6-baseline` |
| ISSUE-010 | P0 | fixed | Governance treated unmerged PR records as already immutable and blocked evidence refinement | BC-013; TR-CI-20260723-003, TR-CI-20260723-004 | `codex/ci-swift6-baseline` |
| ISSUE-011 | P2 | open | `actions/checkout@v4` uses a deprecated Node 20 action runtime | BC-014 | `codex/ci-action-runtime` |
| ISSUE-012 | P2 | open | High-frame validator calls Pillow APIs scheduled for removal in Pillow 14 | BC-015 | `codex/pillow14-validator` |
| ISSUE-013 | P0 | wont-fix | GitHub Free cannot enforce branch protection on this private repository; owner accepts procedural PR control | BC-016; TR-GITHUB-20260723-001, TR-GITHUB-20260723-002 | repository settings |
| ISSUE-014 | P0 | fixed | Push-to-main CI revalidated the entire repository as if every historical record were newly added | BC-017; TR-CI-20260723-005 | `codex/ci-swift6-baseline` |
