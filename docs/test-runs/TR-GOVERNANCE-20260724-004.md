# TR-GOVERNANCE-20260724-004 — Automatic next-task handoff

- Status: pass
- Date: 2026-07-24T15:04:10+08:00
- Content-SHA256: 59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8
- Commit/Tree: `codex/visual-defect-tracking-rule` post-`686f94a` candidate
- System: macOS 26.5.2 (25F84), Apple silicon
- Xcode: 26.6 (17F113)
- Swift: 6.3.3 (swiftlang-6.3.3.1.3)
- ISSUE: GitHub #15
- BC: none
- CHG: CHG-20260724-002

## Tested content

The required end-of-batch routing rule in `AGENTS.md`, its full handoff
template, and the corresponding execution-plan and CHG revisions.

## Commands

```sh
git diff --check
python3 Scripts/check_governance.py digest
python3 Scripts/check_governance.py --staged
```

## Passed

- The working diff contains no whitespace errors.
- The governed-content digest remains
  `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`.
- The staged governance check accepts the AGENTS rule, plan/CHG revision,
  handoff template, and this immutable TR.

## Failed

None.

## Skipped

Product, package, renderer, asset, Swift, and device tests were skipped because
the candidate changes only Markdown task-routing and handoff guidance.

## Failure analysis

Not applicable.

## Evidence

The route table distinguishes context isolation from filesystem isolation:
sequential work defaults to a new Local task, while a new Worktree is limited
to independent work from an exact committed base on a different branch.

The template requires a concrete checkpoint, route, user action, next scope,
non-goals, exit gate, and copyable Prompt without unresolved placeholders.

## Retrospective

Saying “start a new task” is insufficient unless the preceding task also
records the exact durable state and generates the next bounded Prompt. Making
that an AGENTS rule allows later tasks to repeat the handoff consistently.
