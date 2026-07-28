# Codex visual-remediation batch handoff

## Durable checkpoint

- Completed batch: `B4 production asset rebuild train — foundation color-correction prerequisite only`
- Completion state: `complete; user-accepted correction reviewed and squash-merged`
- Repository: `/Users/oops/Documents/养猫爱猫计划`
- Current branch: `main`
- Accepted product checkpoint:
  `main@144390af4a3451f079608edc6b6e04ae3db8a87d`
- Product PR: [#32](https://github.com/lenxyliu/CatAtWork/pull/32),
  exact final head `23ece48b3c25422a2977ecccfdb92b34fa5662f0`
- Working tree after product merge: `clean; local main and origin/main aligned`
- GitHub Issues updated:
  [#10 accepted](https://github.com/lenxyliu/CatAtWork/issues/10#issuecomment-5106170682),
  [#21 accepted](https://github.com/lenxyliu/CatAtWork/issues/21#issuecomment-5106173643),
  [#15 accepted](https://github.com/lenxyliu/CatAtWork/issues/15#issuecomment-5106176368)
- Records/evidence: ADR-0017; CHG-20260728-001/002;
  TR-ASSET-20260728-019..023; TR-GOVERNANCE-20260728-009..012;
  TR-GITHUB-20260728-004/005
- Accepted package evidence: partial native manifest
  `b9434a2c9fa4eeb02b2ba36e0ae2db29af37f8c2a9eddcded2464fb1bb5bc9c6`;
  governed content digest
  `b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce`
- Verification: 12/12 source-effect color/detail oracle; 3,802/3,802 B2;
  15/15 foundation; 216/216 color-only and LFS; targeted Python 6/6; full
  Python 43/43; independent fresh Swift 64/64; byte-identical deterministic
  double package; at least five native loops each for
  idle/walkLeft/walkRight/runLeft/runRight; exact-head hosted governance and
  Swift/package; procedural review 4798747648
- Preservation proof: animation spec, alpha/geometry/scale/pose, 544 unscoped
  frames, interaction assets, physical actions, generated atlases and runtime
  package unchanged
- Interaction checkpoint: product work
  `31d8ab14540e856c381613f98f29b540c472ebb8`; documentation-only handoff head
  `ae6e435c4fbab2d80e9c569f4049b3109758a8a3`
- Native instances: rejected equal-weight PID 38531 closed at the user's
  request; accepted PID 96878 remained running for direct attribution
- Follow-up observations: cross-action size inconsistency remains GitHub #11 /
  ISSUE-017 / BC-020. Fast blinking remains un-attributed timing/action
  evidence; reproduce separately before deciding whether it extends #18.
  Neither was modified or accepted as fixed here.

## Route decision

- Route: `NEW_LOCAL_TASK`
- Reason: the color prerequisite is fully merged. Any interaction resumption
  must reconcile its preserved checkpoint with the accepted foundation color
  contract in a new bounded batch. The fast-blink and size observations need
  separate authorization and must not be folded into interaction implicitly.
- User action: open a new task only when ready to resume the interaction
  production slice or explicitly commission one of the non-color follow-ups.

## Next task

- Batch: `B4 production asset rebuild train — interaction resume after accepted foundation color prerequisite`
- Goal: reconstruct the preserved interaction candidate on the accepted
  foundation color oracle, revalidate its exact seated endpoints, and resume
  only the interaction slice through direct native acceptance and reviewed PR.
- Primary Issues: GitHub #10, #21 and master #15; retain existing interaction
  Issue/BC links from CHG-20260727-004
- Starting point:
  `main@144390af4a3451f079608edc6b6e04ae3db8a87d`
- Preserved source checkpoint:
  `codex/default-pet-visual-interaction@31d8ab14540e856c381613f98f29b540c472ebb8`
  with documentation-only child
  `ae6e435c4fbab2d80e9c569f4049b3109758a8a3`
- Branch to create/use:
  `codex/default-pet-visual-interaction-resume`
- Scope: the previously bounded 336 interaction frames and the minimum
  deterministic provenance/contract updates required by accepted ADR-0017
- Non-goals: no foundation re-edit; no fast-blink or cross-action-size repair
  without a separately confirmed scope; no physical, integration, B5–B8 or
  release work
- Done when: the interaction source is rebuilt against the accepted color
  oracle, all interaction and preserved foundation gates pass, direct native
  interaction acceptance is recorded, and a reviewed exact-head PR is
  squash-merged without starting later slices

## Copyable Prompt

```text
Resume only the B4 interaction production slice in
/Users/oops/Documents/养猫爱猫计划.

Start from exact accepted product checkpoint
main@144390af4a3451f079608edc6b6e04ae3db8a87d and create/use
codex/default-pet-visual-interaction-resume. Read AGENTS.md, CONTRIBUTING.md,
PLAN-20260724-PET-VISUAL-REMEDIATION.md, ADR-0016/0017,
CHG-20260727-004, BC-019, TR-ASSET-20260728-017/018,
TR-GITHUB-20260728-002/003, every comment on GitHub #10/#21/#15, and the
preserved interaction checkpoint
codex/default-pet-visual-interaction@31d8ab14540e856c381613f98f29b540c472ebb8
under documentation-only head
ae6e435c4fbab2d80e9c569f4049b3109758a8a3.

The foundation color prerequisite is accepted and merged by PR #32. Its
native partial manifest is
b9434a2c9fa4eeb02b2ba36e0ae2db29af37f8c2a9eddcded2464fb1bb5bc9c6,
governed digest is
b15b804df0d15a771a5fa6a20152b12cd7fcddf91574de5645853cd5807f64ce,
and all 216 foundation frames must remain byte-identical. Rebuild/reconcile
only the previously bounded 336 interaction frames against ADR-0017, preserve
exact seated endpoints, run the full interaction/foundation/non-regression
matrix, obtain direct native interaction acceptance, and publish through a
reviewed exact-head PR.

Do not treat the user's fast-blink or cross-action-size observations as
authorized interaction fixes. Cross-action size remains #11; blink needs a
separate timing reproduction before attribution to #18 versus authored blink
duration. Do not modify physical actions, integration, B5–B8 or release
artifacts.
```
