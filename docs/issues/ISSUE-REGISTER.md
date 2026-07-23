# Issue register

The root `ISSUE-CLASSIFICATION.md` is a frozen pre-governance snapshot. Its rows have stable migrated IDs in `LEGACY-ISSUE-MAP.md`; later status is recorded here or in new immutable evidence, never by editing the snapshot.

| ID | Priority | Status | Summary | Badcase | Planned branch |
| --- | --- | --- | --- | --- | --- |
| ISSUE-001 | P1 | open | Priority reordering can invalidate pose transitions precomputed at enqueue | BC-001 | `codex/action-state-machine` |
| ISSUE-002 | P1 | open | `.catpet` capability/pose/next/scale/fallback contract is inconsistently applied | BC-002, BC-003, BC-004 | `codex/pet-package-contract` |
| ISSUE-003 | P1 | open | Import/image work can block the main thread; process pipes and texture loads are unsafe | BC-005, BC-006 | `codex/background-asset-io` |
| ISSUE-004 | P2 | open | Window controller duplicates runtime state and prevents focused App integration tests | BC-007 | `codex/runtime-controller-split` |
| ISSUE-005 | P0 | in-progress | Loose Git objects and build/history artifacts need verified preservation and clean baseline | BC-008 | baseline |
| ISSUE-006 | P1 | fixed | Design, defect, badcase and test history can be overwritten or omitted | BC-009; TR-GOVERNANCE-20260723-001 | baseline |
