# Repository rules for agents and automation

These rules apply to every AI agent, script, and automated change in this repository.

## Before changing anything

1. Read `CONTRIBUTING.md`, `docs/issues/ISSUE-REGISTER.md`, and the design documents relevant to the affected subsystem.
2. Read every linked ISSUE and badcase. Do not rely on a summary when the original record is available.
3. Create a branch named `codex/<short-purpose>` unless establishing the one-time clean baseline. Never develop directly on `main` after that baseline is pushed.
4. Create a new `CHG-YYYYMMDD-NNN` record before a non-trivial change. A fix or optimization also requires a stable ISSUE and at least one independent BC record.
5. If the change affects architecture, privacy, security, a data/package contract, asset format, or release policy, update the relevant evolving design document and create a new ADR. Never rewrite an accepted ADR.

## While changing

- Keep production artwork separate from generated drafts and QA previews. Do not stage a production raster until `git lfs install` has succeeded and `git check-attr filter <file>` reports `lfs`.
- `Sources/CatAtWork/Resources/DefaultPet.catpet` is the only runtime default-pet source. Do not recreate `Resources/DefaultPets`.
- Do not run `git gc`, `git prune`, delete `.git/objects`, replace `.git`, or remove historical archives unless the recovery manifest is verified and the user has approved the exact targets.
- Do not overwrite or delete historical CHG, ADR, TR, audit, badcase, release-manifest, or baseline evidence. Supersede with a new record.
- Keep the ISSUE and BC status at `fixed-unverified` until a passing, content-matched TR exists. Use `fixed` only after automated verification; keep real-device acceptance as a separate status when required.
- Preserve failed tests. A rerun is a new TR, never an edit that erases the failure.

## Defect discovery and analysis

- GitHub Issues in `lenxyliu/CatAtWork` are the source of truth for active defects. The master visual-defect register is GitHub issue `#15`.
- Work under the visual-remediation program must begin by reading `docs/plans/PLAN-20260724-PET-VISUAL-REMEDIATION.md`. Use one bounded plan batch per branch and primary Codex task, and update the plan handoff ledger before ending that batch.
- Before continuing analysis of a newly observed defect, search GitHub Issues. Add evidence to an existing issue when the symptom and root-cause scope match; otherwise create a new issue and link it from `#15`.
- Keep confirmed facts, direct evidence, root-cause hypotheses, and pending verification explicitly separated. Never present a hypothesis as a confirmed cause.
- Append dated evidence and analysis updates. Do not delete failed evidence or rewrite history to make a defect appear resolved.
- Every defect issue must contain reproduction evidence, expected and actual behavior, impact, a solution direction, and measurable acceptance criteria.
- Do not mark a defect fixed without content-matched automated evidence. Record native-screen/device acceptance separately from automated status.
- Do not publish private screen-recording content or local absolute paths in a public issue. Record only the minimum pet-related timestamps; crop and redact evidence before governed publication.
- An analysis-only request authorizes defect discovery, solution design, and acceptance design, but not production code or asset changes.

## Before handing off or opening a PR

1. Run `python3 Scripts/check_governance.py --base <merge-base>`.
2. Run all tests required by the affected design document and record exact commands, environment, results, evidence paths, and the governed-content digest in a new TR.
3. Finalize the CHG with compatibility and rollback notes and links to ISSUE/ADR/BC/TR.
4. Update `CHANGELOG.md` only for user-visible changes.
5. Confirm no generated previews, build products, applications, DMGs, credentials, or non-LFS production rasters are staged.

The only trivial exemption is a PR labeled `governance:trivial` whose diff consists exclusively of Markdown spelling, formatting, or whitespace. Executable code, tests, scripts, configuration, schemas, hooks, workflows, and binary assets can never use this exemption.
