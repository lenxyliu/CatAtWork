# Issue register

The root `ISSUE-CLASSIFICATION.md` is a frozen pre-governance snapshot. Its rows have stable migrated IDs in `LEGACY-ISSUE-MAP.md`; later status is recorded here or in new immutable evidence, never by editing the snapshot.

| ID | Priority | Status | Summary | Badcase | Planned branch |
| --- | --- | --- | --- | --- | --- |
| ISSUE-001 | P1 | fixed | Priority reordering can invalidate pose transitions precomputed at enqueue | BC-001; TR-ACTION-20260723-001 | `codex/action-state-machine` |
| ISSUE-002 | P1 | fixed | `.catpet` capability/pose/next/scale/fallback contract is inconsistently applied | BC-002, BC-003, BC-004; TR-PACKAGE-20260723-002 | `codex/pet-package-contract` |
| ISSUE-003 | P1 | fixed | Import/image work can block the main thread; process pipes and texture loads are unsafe | BC-005, BC-006; TR-IO-20260723-006 | `codex/background-asset-io` |
| ISSUE-004 | P2 | fixed | Window controller duplicates runtime state and prevents focused App integration tests | BC-007; TR-RUNTIME-20260723-002 | `codex/runtime-controller-split` |
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
| ISSUE-015 | P1 | open / current-confirmed | Intra-action geometry, size and silhouette discontinuity ([GitHub #9](https://github.com/lenxyliu/CatAtWork/issues/9)) | BC-018 | `codex/default-pet-visual-*` |
| ISSUE-016 | P1 | open / current-confirmed | Adjacent and cross-action material-color discontinuity ([GitHub #10](https://github.com/lenxyliu/CatAtWork/issues/10)) | BC-019 | `codex/default-pet-visual-*` |
| ISSUE-017 | P1 | open / current-confirmed | Cross-action character scale and proportion discontinuity ([GitHub #11](https://github.com/lenxyliu/CatAtWork/issues/11)) | BC-020 | `codex/canonical-pet-asset-contract`; `codex/default-pet-visual-*` |
| ISSUE-018 | P1 | open / current-confirmed | Root-relative body and support instability ([GitHub #12](https://github.com/lenxyliu/CatAtWork/issues/12)) | BC-021 | `codex/canonical-pet-asset-contract`; `codex/default-pet-visual-*` |
| ISSUE-019 | P1 | open / current-confirmed | Locomotion can run at near-zero velocity and is not phase-bound to displacement ([GitHub #13](https://github.com/lenxyliu/CatAtWork/issues/13)) | BC-022 | `codex/display-time-locomotion` |
| ISSUE-020 | P0 | open / current-confirmed | Visual validator returns green with confirmed continuity failures ([GitHub #14](https://github.com/lenxyliu/CatAtWork/issues/14)) | BC-023 | `codex/visual-qa-gates` |
| ISSUE-021 | P1 | open / current-confirmed | Production frames contain detached visible components ([GitHub #16](https://github.com/lenxyliu/CatAtWork/issues/16)) | BC-024 | `codex/default-pet-visual-*` |
| ISSUE-022 | P1 | open / current-confirmed | Action endpoints disagree with `startPose`/`endPose` declarations ([GitHub #17](https://github.com/lenxyliu/CatAtWork/issues/17)) | BC-025 | `codex/canonical-pet-asset-contract`; `codex/default-pet-visual-*` |
| ISSUE-023 | P1 | open / current-confirmed | The 30 Hz animation clock quantizes authored 12/14/18 fps cadence ([GitHub #18](https://github.com/lenxyliu/CatAtWork/issues/18)) | BC-026 | `codex/display-time-locomotion` |
| ISSUE-024 | P1 | open / current-confirmed | Async atlas replacement renders transparent samples under delay injection ([GitHub #19](https://github.com/lenxyliu/CatAtWork/issues/19)) | BC-027 | `codex/atomic-render-snapshot` |
| ISSUE-025 | P1 | open / historical-regression | Historical gaze/body coupling does not reproduce in the content-matched current build ([GitHub #20](https://github.com/lenxyliu/CatAtWork/issues/20)) | BC-028 | `codex/gaze-body-regression` |
| ISSUE-026 | P1 | open / current-confirmed | Local face, eye, coat and anatomy identity drifts across frames/actions ([GitHub #21](https://github.com/lenxyliu/CatAtWork/issues/21)) | BC-029 | `codex/canonical-pet-asset-contract`; `codex/default-pet-visual-*` |
| ISSUE-027 | P0 | fixed / current-confirmed | Visual QA has no deterministic baseline/release finding contract or fail-closed release policy ([GitHub #14](https://github.com/lenxyliu/CatAtWork/issues/14)) | BC-030; TR-VISUAL-20260726-002..007; TR-GITHUB-20260726-009 | `main@72d2154afbe590654ce5c21be7363d9c67ac267f` |

## 2026-07-28 B4 foundation candidate evidence

- Candidate 6 passed the then-current numeric gate but failed native review:
  its single light/warm bridge visibly changed the canonical coat identity
  (`ISSUE-016`, `ISSUE-026`), and `walkLeft`/`runLeft` faced right while the
  mirrored Right actions faced left (`ISSUE-022`). The user-observed backward
  locomotion and the agent's contact-sheet confirmation are preserved in
  `TR-ASSET-20260727-015`.
- The foundation validator now measures canonical light, warm and dark groups
  independently and checks absolute locomotion-facing direction on every
  walk/run frame. Candidate 7 and candidate 8 failures remain immutable in
  `TR-ASSET-20260727-017` and `TR-ASSET-20260727-018`; neither was installed.
- Candidate 9 is the locally accepted foundation candidate. Its action-scoped
  B2 report passes 3,802 observations with zero findings, all 14 foundation
  checks pass, the full Python and fresh-path Swift suites pass, and native
  fixed-background review covers at least five loops of `idle`, `walkLeft`,
  `walkRight`, `runLeft` and `runRight`. Content-matched acceptance is
  preserved in `TR-ASSET-20260727-020`; the affected Issues stay open until
  the reviewed foundation PR is merged and later B4 families are evaluated.
- Production `previewAnimation` intentionally sets horizontal velocity to
  zero, so fixed-background loop review is not a displacement test. The
  already registered near-zero/phase-bound runtime concern remains
  `ISSUE-019` for the B5 display-time locomotion slice; no B5 runtime behavior
  is changed by this B4 asset branch.
