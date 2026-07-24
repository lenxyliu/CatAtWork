# Codex visual-remediation batch handoff template

Fill this template before the final response of every visual-remediation batch
completion, pause, or blocker. Replace every bracketed field. Do not emit an
unresolved Prompt.

## Durable checkpoint

- Completed batch: `[B# and name, or none]`
- Completion state: `[complete | partial | blocked | failed-preserved]`
- Repository: `/Users/oops/Documents/养猫爱猫计划`
- Current branch: `[exact branch]`
- Base branch and commit: `[exact base and SHA]`
- Latest durable commit: `[exact SHA]`
- Working tree: `[clean | exact intentional dirty paths]`
- PR/merge state: `[not pushed | pushed URL | PR URL/state | merged commit]`
- GitHub Issues updated: `[exact numbers and comment links]`
- Records/evidence: `[ISSUE/BC/ADR/CHG/TR/audit IDs and evidence paths]`
- Tests: `[passed, failed, skipped; exact records]`
- Unresolved blocker/risk: `[none or exact blocker]`

## Route decision

- Route: `[CONTINUE_CURRENT | NEW_LOCAL_TASK | NEW_WORKTREE | STOP_BLOCKED]`
- Reason: `[one concrete sentence based on the plan routing table]`
- User action:
  1. `[exact UI/navigation action]`
  2. `[exact project, Local/Worktree, and starting branch selection]`
  3. `Paste the Prompt below without adding a chat-history summary.`

## Next task

- Batch: `[exact B# and name]`
- Goal: `[one bounded outcome]`
- Primary Issues: `[exact GitHub Issue numbers]`
- Starting point: `[exact accepted branch/commit]`
- Branch to create/use: `[exact codex/<purpose> branch]`
- Scope: `[included files/subsystem/work]`
- Non-goals: `[explicitly excluded next batches or product changes]`
- Done when: `[exact batch exit gate]`

## Copyable Prompt

```text
Continue PLAN-20260724-PET-VISUAL-REMEDIATION, batch [B# and name] only.

Repository: /Users/oops/Documents/养猫爱猫计划
Starting branch/commit: [exact branch and SHA]
Branch to create/use before edits: [exact codex/<purpose> branch]
Primary GitHub Issues: [exact numbers]

Goal:
[bounded goal]

Before changing anything:
1. Read AGENTS.md, CONTRIBUTING.md,
   docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md, GitHub #15, every
   scoped child Issue and comment, and every linked local
   ISSUE/BC/design/ADR/CHG record.
2. Run git status --short --branch and inspect recent commits. Confirm the
   checkout matches [exact branch/SHA] and the working tree is clean.
3. Reproduce or verify [exact badcase, failing oracle, PR state, or merge
   prerequisite] before making changes.
4. Create the required CHG before non-trivial changes and create/update an ADR
   only when the repository rules require one.

Scope:
- [included item]

Non-goals:
- [excluded item]
- Do not begin [next batch].

Required verification and evidence:
- [exact commands, device checks, or PR checks]
- Preserve failed runs in new TR records; never overwrite them.
- Update the affected GitHub Issues, #15, and the plan ledger with evidence,
  not conclusions copied from a prior chat.

Done when:
- [exact exit criterion]

Before your final response:
1. Commit every intended durable file and report the exact branch, base,
   commit, working-tree state, PR/merge state, tests, evidence, and blockers.
2. Fill docs/templates/CODEX-BATCH-HANDOFF-TEMPLATE.md.
3. Choose exactly one next route: CONTINUE_CURRENT, NEW_LOCAL_TASK,
   NEW_WORKTREE, or STOP_BLOCKED.
4. Give me the fully resolved, copyable Prompt for the following task. Do not
   leave placeholders and do not start the following batch.
```

## Routing reminders

- A fresh Local task is the sequential default and resets chat context while
  continuing in the main local checkout.
- A Worktree is optional isolation for independent work; it does not reduce
  context use by itself.
- One Git branch may be checked out in only one worktree at a time.
- Create a real `codex/<purpose>` branch in a new Worktree before editing.
- Use Codex App Handoff to move the same task and code between Worktree and
  Local when native/device validation requires the Local environment.
- If the base commit, required merge, or clean state is unknown, stop with
  `STOP_BLOCKED` and provide an unblocking Prompt rather than guessing.
