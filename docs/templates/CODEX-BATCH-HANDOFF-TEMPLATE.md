# Codex visual-remediation batch handoff

## Durable checkpoint

- Completed batch: `none; B4 interaction PR slice paused before production`
- Completion state: `blocked`
- Repository: `/Users/oops/Documents/养猫爱猫计划`
- Current branch: `codex/default-pet-visual-interaction`
- Base branch and commit:
  `main@4011d2d8c8fc4559ee1da911a8b9b29fd720d16f`
- Latest durable interaction checkpoint:
  `31d8ab14540e856c381613f98f29b540c472ebb8`
- Working tree: `clean after this handoff-only commit`
- PR/merge state: remote checkpoint branch pushed; no PR opened because native
  color acceptance failed before production installation
- GitHub Issues updated:
  [#10 blocker](https://github.com/lenxyliu/CatAtWork/issues/10#issuecomment-5102979340)
  and
  [#15 checkpoint](https://github.com/lenxyliu/CatAtWork/issues/15#issuecomment-5102979608)
- Records/evidence: ISSUE-015/016/017/018/021/022/026;
  BC-018/019/020/021/024/025/029; ADR-0016; CHG-20260727-004;
  TR-ASSET-20260728-001..018; TR-GOVERNANCE-20260728-004..008;
  TR-GITHUB-20260728-002/003; isolated source root
  `/private/tmp/catatwork-b4-interaction-generation.OfpeFC`; candidate 4
  `/private/tmp/catatwork-b4-interaction-candidate.4`; validation SHA-256
  `8047bae13e8610100da7fef4ecdc256a449d25032a92c966c3800546540db545`
- Tests: passed 44/44 full Python tests, 6,310/6,310 candidate-4
  action-scoped B2 observations, seven/seven interaction checks, 33-path
  branch governance and diff check; failures preserved in
  TR-ASSET-20260728-001/002/004..017, TR-GOVERNANCE-20260728-004..007 and
  TR-GITHUB-20260728-002; skipped production install/LFS, candidate-4 native
  acceptance, full package, fresh-path Swift, hosted checks, PR/review/merge,
  physical, integration, B5–B8 and release
- Unresolved blocker/risk: the user accepts the generated effect-sheet color
  but rejects the frozen palette-normalized production appearance; sampled
  `waiting` pose 0 has 99.205807% opaque-pixel rewriting and dark-material
  source-to-normalized ΔE00 7.225664. Exact frozen seated endpoints make an
  interaction-only color exception illegal and visibly discontinuous.

## Route decision

- Route: `NEW_LOCAL_TASK`
- Reason: the interaction branch is a durable blocked checkpoint, while the
  required correction changes the already accepted foundation color contract
  and must be reviewed as a separate sequential prerequisite.
- User action:
  1. In Codex, create a new Local task.
  2. Select `/Users/oops/Documents/养猫爱猫计划`, start from
     `main@4011d2d8c8fc4559ee1da911a8b9b29fd720d16f`, and do not create a
     Worktree.
  3. Paste the Prompt below without adding a chat-history summary.

## Next task

- Batch: `B4 production asset rebuild train — foundation color-correction prerequisite only`
- Goal: replace the rejected palette-normalized foundation color target with
  the user-accepted source-effect target while preserving every non-color
  ADR-0016 invariant.
- Primary Issues: GitHub #10 and #21; master #15
- Starting point:
  `main@4011d2d8c8fc4559ee1da911a8b9b29fd720d16f`
- Branch to create/use:
  `codex/default-pet-visual-foundation-color-correction`
- Scope: foundation color contract/normalization, the same nine foundation
  actions and 216 frames, source-effect/color metrics, deterministic package
  evidence and native fixed-background color acceptance
- Non-goals: no interaction production installation; no physical or
  integration action; no B5–B8 behavior; no release
- Done when: a reviewed foundation color-correction PR is squash-merged,
  exact final-head hosted governance/Swift pass, local main/origin/main align,
  and the interaction checkpoint can resume against the corrected frozen
  foundation.

## Copyable Prompt

```text
Continue PLAN-20260724-PET-VISUAL-REMEDIATION, batch B4 production
asset rebuild train — foundation color-correction prerequisite only.

Repository: /Users/oops/Documents/养猫爱猫计划
Starting branch/commit:
main at 4011d2d8c8fc4559ee1da911a8b9b29fd720d16f
Branch to create/use before edits:
codex/default-pet-visual-foundation-color-correction
Primary GitHub Issues: #10, #21 and master #15

Goal:
Correct the accepted B4 foundation color target so native production frames
match the user-accepted generated effect-sheet appearance, while preserving
all non-color ADR-0016 invariants. Publish only the reviewed foundation
color-correction prerequisite; do not resume interaction in this task.

Before changing anything:
1. Read AGENTS.md, CONTRIBUTING.md,
   docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md,
   docs/design/ASSET-PIPELINE.md, docs/design/CATPET-CONTRACT.md,
   docs/design/TEST-AND-RELEASE.md, ADR-0016, CHG-20260727-002/003,
   TR-ASSET-20260727-015/020, TR-GITHUB-20260728-001, GitHub #10/#21/#15
   and every comment.
2. Read the blocked interaction checkpoint
   codex/default-pet-visual-interaction@31d8ab14540e856c381613f98f29b540c472ebb8,
   especially CHG-20260727-004, BC-019,
   TR-ASSET-20260728-017/018 and TR-GITHUB-20260728-002/003.
3. Confirm HEAD is exactly
   4011d2d8c8fc4559ee1da911a8b9b29fd720d16f and the worktree is clean,
   then create codex/default-pet-visual-foundation-color-correction.
4. Reproduce the badcase before edits: using
   /private/tmp/catatwork-b4-interaction-generation.OfpeFC/extracted/waiting/000.png,
   prove fixed-canonical-material-palette-pull changes 68,203/68,749 opaque
   pixels (99.205807%) and moves dark-material median by ΔE00 7.225664.
   Verify the native seated PNG is byte-identical to frozen idle/000.png and
   that the repository and preview app use the same Metal sRGB paths.
5. Reproduce candidate 9's accepted foundation oracle from
   /private/tmp/catatwork-b4-foundation-generation.rdcnQP and preserve every
   failed execution under a new TR identity.
6. Create CHG-20260728-001 before non-trivial changes. Because the evidence
   requires a reviewed deviation from ADR-0016's accepted color
   normalization/target, create ADR-0017; do not rewrite ADR-0016.

Scope:
- Correct only the foundation color target/normalization and rebuild exactly
  idle, sitToStand, standToSit, lieDown, getUp, walkLeft, walkRight, runLeft
  and runRight: 216 frames.
- Treat the generated effect-sheet appearance accepted by the user as the
  native visual target. Add a deterministic source-effect-to-authored color
  oracle that fails the current 99.205807% rewrite/ΔE00 7.225664 badcase.
- Preserve 220 px/body-unit, 665×737 canvas, safe margin, root/support,
  identity rig, pose/bridge, component, deformation, facing, no-resize and
  source-to-atlas rules.
- Keep drafts, comparison sheets, metrics and native evidence outside
  production paths. Before staging rasters, run git lfs install and prove all
  216 targets report filter: lfs.

Non-goals:
- Do not install or modify idleEar, idleTail, groom, wave, petting, earPet,
  chinPet, backPet, curious, working, waiting, happy, startled or failed.
- Do not modify bellyPet, pickup, thrown, landing, jump, bellyRoll, sleep or
  wakeUp.
- Do not perform B4 physical or integration/atlas work, B5–B8 changes, or a
  release.

Required verification and evidence:
- Prove every non-color foundation invariant is unchanged and all 216 frames
  retain native scale without resizing/resampling.
- Run foundation B2 action-scoped/release and all foundation custom gates,
  the new source-effect color oracle, full Python, fresh-path Swift, package,
  deterministic double build, diff, LFS and governance checks.
- Run at least five native fixed-background loops each for idle, walkLeft,
  walkRight, runLeft and runRight, including direct user color acceptance
  against the generated effect-sheet target.
- Confirm all 336 interaction frames, all eight physical actions, generated
  atlases and the runtime default package are unchanged.
- Update #10, #21 and #15. Publish only through a reviewed PR whose exact
  final head passes hosted governance and Swift, then squash merge and align
  local main/origin/main.

Done when:
- The user accepts the native foundation color against the effect-sheet
  target, all 216 corrected foundation frames pass the reviewed gates, and
  the foundation color-correction PR is squash-merged.
- B4 remains in progress; the remote interaction checkpoint remains preserved
  but not resumed, and physical/integration remain not started.

Before the final response:
1. Report exact branches, commits, PRs, checks, records, failures and skips.
2. Fill docs/templates/CODEX-BATCH-HANDOFF-TEMPLATE.md.
3. Choose exactly one next route and provide its fully resolved Prompt.
4. Do not begin interaction, physical, integration or any later batch.
```
