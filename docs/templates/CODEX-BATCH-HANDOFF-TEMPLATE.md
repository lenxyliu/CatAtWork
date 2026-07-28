# Codex visual-remediation batch handoff

## Durable checkpoint

- Completed batch: `B4 production asset rebuild train — foundation PR slice`
- Completion state: `complete`
- Repository: `/Users/oops/Documents/养猫爱猫计划`
- Current branch: `codex/close-b4-foundation-publication`
- Base branch and commit:
  `main@48ae9466e460ddbeab5d7b39a245760614568448`
- Latest durable closure checkpoint:
  `83e05f06ebbf2d48b8c75bd46cdf408196be8464`
- Working tree: `clean after this handoff-only commit`
- PR/merge state: foundation
  [PR #30](https://github.com/lenxyliu/CatAtWork/pull/30) final head
  `3b39c0f7385fcbb288d7eebc589fa5a00df324f3` passed hosted checks and review,
  then squash-merged as `48ae9466e460ddbeab5d7b39a245760614568448`
- GitHub Issues updated:
  [#9 accepted](https://github.com/lenxyliu/CatAtWork/issues/9#issuecomment-5100105592),
  [#10 accepted](https://github.com/lenxyliu/CatAtWork/issues/10#issuecomment-5100105757),
  [#11 accepted](https://github.com/lenxyliu/CatAtWork/issues/11#issuecomment-5100106098),
  [#12 accepted](https://github.com/lenxyliu/CatAtWork/issues/12#issuecomment-5100105934),
  [#16 accepted](https://github.com/lenxyliu/CatAtWork/issues/16#issuecomment-5100106410),
  [#17 accepted](https://github.com/lenxyliu/CatAtWork/issues/17#issuecomment-5100106258),
  [#21 accepted](https://github.com/lenxyliu/CatAtWork/issues/21#issuecomment-5100106569)
  and
  [#15 accepted](https://github.com/lenxyliu/CatAtWork/issues/15#issuecomment-5100106730);
  pre-merge links are preserved in TR-GITHUB-20260728-001
- Records/evidence: ISSUE-015/016/017/018/021/022/026;
  BC-018/019/020/021/024/025/029; ADR-0016; CHG-20260727-002/003;
  TR-ASSET-20260727-001..020; TR-GOVERNANCE-20260728-001..003;
  TR-GITHUB-20260728-001; candidate 9 report
  `a7dac35f8c146a9d38ec8738f29b053b21ca41def9c287f08ab6373c59b3136d`;
  package tree
  `7ce479226a327cd7736c20aa5ff5bc2f48ffdcc394cfdb5555dcbda2d4d843cc`
- Tests: passed 3,802/3,802 B2 observations, 14/14 foundation gates,
  15 targeted Python tests, 40 full Python tests, 64 fresh-path Swift XCTest
  cases, runtime package validation, deterministic double build, all 216 LFS
  checks, five native loops for each scoped looped action, local governance and
  hosted governance/Swift; failed executions are preserved in
  TR-ASSET-20260727-001/003/006..019 and TR-GOVERNANCE-20260728-001; skipped
  interaction, physical, integration, B5–B8, release, tag, DMG and GitHub
  Release
- Unresolved blocker/risk: none; GitHub #13/ISSUE-019 remains the separate B5
  display-time locomotion problem and was not changed by the foundation slice

## Route decision

- Route: `NEW_LOCAL_TASK`
- Reason: B4 slices are sequential and the accepted foundation must be the
  sole immutable input to a fresh interaction-slice task.
- User action:
  1. In Codex, create a new Local task.
  2. Select `/Users/oops/Documents/养猫爱猫计划` and start from
     `83e05f06ebbf2d48b8c75bd46cdf408196be8464`; do not reuse this task or
     create a Worktree.
  3. Paste the Prompt below without adding a chat-history summary.

## Next task

- Batch: `B4 production asset rebuild train — interaction PR slice only`
- Goal: rebuild the 14 interaction/status actions (336 frames) from the
  accepted frozen foundation without retouching its nine actions.
- Primary Issues: GitHub #9, #10, #11, #12, #16, #17 and #21; master #15
- Starting point:
  `codex/close-b4-foundation-publication@83e05f06ebbf2d48b8c75bd46cdf408196be8464`
- Branch to create/use: `codex/default-pet-visual-interaction`
- Scope: `idleEar`, `idleTail`, `groom`, `wave`, `petting`, `earPet`,
  `chinPet`, `backPet`, `curious`, `working`, `waiting`, `happy`, `startled`
  and `failed`; 336 production frames total
- Non-goals: no foundation retouch; no `bellyPet`, `pickup`, `thrown`,
  `landing`, `jump`, `bellyRoll`, `sleep` or `wakeUp`; no B4 integration/full
  atlas rebuild; no B5–B8 work; no release
- Done when: all 336 interaction frames pass the accepted B2/B3 and frozen
  foundation action-scoped gates, the reviewed interaction PR is
  squash-merged, local main aligns cleanly, and physical/integration remain
  not started

## Copyable Prompt

```text
Continue PLAN-20260724-PET-VISUAL-REMEDIATION, batch B4 production
asset rebuild train — interaction PR slice only.

Repository: /Users/oops/Documents/养猫爱猫计划
Starting branch/commit:
codex/close-b4-foundation-publication at
83e05f06ebbf2d48b8c75bd46cdf408196be8464
Branch to create/use before edits:
codex/default-pet-visual-interaction
Primary GitHub Issues: #9, #10, #11, #12, #16, #17, #21 and master #15

Goal:
Rebuild only idleEar, idleTail, groom, wave, petting, earPet, chinPet,
backPet, curious, working, waiting, happy, startled and failed (336 production
frames total) from the accepted B4 frozen identity/scale/root/color/pose
foundation.

Before changing anything:
1. Read AGENTS.md, CONTRIBUTING.md,
   docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md,
   docs/design/ASSET-PIPELINE.md, docs/design/CATPET-CONTRACT.md,
   docs/design/TEST-AND-RELEASE.md, ADR-0016, CHG-20260727-002,
   CHG-20260727-003, TR-ASSET-20260727-015,
   TR-ASSET-20260727-020, TR-GITHUB-20260728-001, GitHub #15 and every
   comment on #9/#10/#11/#12/#16/#17/#21.
2. Read ISSUE-REGISTER.md, ISSUE-015/016/017/018/021/022/026,
   BC-018/019/020/021/024/025/029 and all linked evidence.
3. Run git status --short --branch, git log -5 --oneline --decorate,
   git rev-parse HEAD and confirm the checkout is exactly
   83e05f06ebbf2d48b8c75bd46cdf408196be8464 with a clean worktree.
4. Create codex/default-pet-visual-interaction before edits.
5. Reproduce the accepted candidate 9 foundation oracle and the scoped
   interaction badcases before modifying production artwork. Prove the nine
   accepted foundation actions and their digest are unchanged.
6. Create CHG-20260727-004 before non-trivial changes. Do not create a new
   ADR unless evidence requires a reviewed deviation from ADR-0016.
7. Before any production raster is staged, run git lfs install and verify
   git check-attr filter <path> reports lfs for every raster target.

Scope:
- Rebuild exactly idleEar, idleTail, groom, wave, petting, earPet, chinPet,
  backPet, curious, working, waiting, happy, startled and failed: 336 frames.
- Reuse Config/DefaultPet/foundation-contract.json without weakening or
  silently changing its 220 px/body-unit scale, 665×737 canvas,
  root/support, canonical material, identity, pose, component and
  deformation rules.
- Preserve seated endpoints and legal bridges, petting direction semantics,
  comparable material ROIs and action-family intent.
- Produce deterministic root/head-aligned sheets, repeated-action previews,
  metrics and native fixed-background evidence outside production paths.

Non-goals:
- Do not modify idle, sitToStand, standToSit, lieDown, getUp, walkLeft,
  walkRight, runLeft or runRight.
- Do not rebuild bellyPet, pickup, thrown, landing, jump, bellyRoll, sleep or
  wakeUp.
- Do not perform the B4 integration/full-package atlas rebuild or manually
  edit generated atlas output.
- Do not change B5 locomotion timing/display behavior, B6 rendering, B7 gaze
  behavior or begin B8.
- Do not create a release, tag, DMG or GitHub Release.

Required verification and evidence:
- Prove all 336 scoped frames use the accepted frozen
  scale/canvas/root/identity/color system with no action-level or per-frame
  resize.
- Prove all seated endpoints and interaction bridges are legal, petting
  direction semantics are stable and no unapproved disconnected components
  exist.
- Run B2 in action-scoped and release form. Any changed finding set must be
  limited to the reviewed interaction remediation; never rewrite the accepted
  baseline to hide remaining defects.
- Run the full Python suite, fresh-path Swift suite, canonical package checks,
  git diff check and governance check.
- Run native fixed-background review for at least five loops each of petting,
  curious, working and waiting, and repeated complete plays for every scoped
  non-looped action; record exact immutable evidence.
- Preserve each failed execution in a new TR and rerun it under a new TR
  identity.
- Keep drafts, contact sheets, loops and generated QA artifacts outside
  production paths and Git.
- Confirm all nine foundation actions, all eight physical actions, generated
  atlases and the runtime default package are unchanged.
- Append exact evidence to the affected child Issues and #15.
- Publish only through a reviewed PR whose exact final head passes hosted
  governance and Swift checks.

Done when:
- The 14 interaction/status actions and all 336 frames meet the accepted
  B2/B3 and frozen-foundation action-scoped gates.
- Every production raster is verified as Git LFS before staging.
- No foundation, physical, integration or later-batch production content
  changed.
- CHG/TR/Issue evidence and the plan ledger are current.
- The reviewed interaction PR is squash-merged and local main/origin/main
  align cleanly.
- B4 remains in progress; physical and integration slices remain not started.

Before the final response:
1. Report exact branches, commits, PRs, checks, records, tests, failures,
   skips and blockers.
2. Fill docs/templates/CODEX-BATCH-HANDOFF-TEMPLATE.md.
3. Choose exactly one next route and provide a fully resolved Prompt.
4. Do not start the physical, integration or any later batch.
```
