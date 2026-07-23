# Contributing and change traceability

This repository uses a design-to-release evidence chain:

`ISSUE -> BC -> design/ADR -> CHG -> implementation -> TR -> audit/release`

## Branch and PR workflow

- The one-time recovered baseline may be created on `main`. After its first push, all work uses `codex/<purpose>` branches and pull requests.
- Use pull requests for `main`, require `governance` and `swift` to pass, and
  use squash merge. Never force-push or delete `main`.
- Server enforcement is preferred. The owner has explicitly accepted that the
  GitHub Free private repository cannot enforce branch protection and will not
  purchase a paid plan. Therefore every merge requires a manual check of the
  final PR head and passing Actions; this procedural control is weaker than
  branch protection and must not be described as equivalent.
- One defect or coherent design change per branch. Split unrelated work even if it was discovered during the same review.
- A PR is not complete while its ISSUE/BC is `fixed-unverified`, its TR digest is stale, or required real-device acceptance is absent.

## Record types

| Record | Purpose | Mutation rule |
| --- | --- | --- |
| `ISSUE-NNN` | Stable problem/optimization identity and lifecycle | Append status events; never delete history |
| `BC-NNN` | Independent reproduction, expected/actual, cause and regression oracle | Append evidence/status; never erase prior evidence |
| `ADR-NNNN` | One architecture or policy decision | Accepted records are immutable; supersede with a new ADR |
| `CHG-YYYYMMDD-NNN` | Scope, risk, implementation, compatibility and rollback for one change | Editable only within its originating PR; immutable after merge |
| `TR-*` | One test execution, including failures and skips | Immutable; every rerun gets a new ID |
| `AUDIT-*` | One candidate-build completion/release review | Immutable; one record per candidate |

Templates in `docs/templates/` define required fields. IDs are allocated by choosing the next unused number; an ID is never reused.

## Status vocabulary

- `open`: reproduced or accepted, implementation not complete.
- `in-progress`: active implementation exists only on a branch.
- `fixed-unverified`: implementation is complete but no passing content-matched TR exists.
- `fixed`: automated acceptance passed and is linked.
- `device-pending`: automated acceptance passed but explicit real-device acceptance remains.
- `closed`: all required automated and device/release evidence is present.
- `blocked-external`: implementation is ready but a named hosting, account,
  permission, hardware or owner decision prevents the required gate.
- `wont-fix` / `duplicate`: retained with rationale and links; never deleted.

## Required scope

Every non-trivial modification to code, tests, production assets, scripts, schemas, workflows, hooks, build/release configuration, or package metadata requires a CHG. Fixes and optimizations additionally require ISSUE, BC, and a passing TR matching the final governed-content digest.

Architecture, privacy, security, `.catpet` contract, asset format/pipeline, and test or release-policy changes require both an evolving design update and a new ADR. Design documents append a revision row containing the CHG ID.

## Test records and freshness

Compute the digest with:

```sh
python3 Scripts/check_governance.py digest
```

Put that exact value in `Content-SHA256` of the TR. If governed code, tests, production assets, scripts, schemas, workflows, hooks, package metadata, or configuration changes afterwards, the TR becomes stale and validation must be rerun under a new TR ID.

## Trivial exemption

`governance:trivial` is allowed only for Markdown spelling, formatting, or whitespace. The PR must explain why meaning is unchanged. It is rejected for any executable, configuration, schema, workflow, hook, test, or binary change.

## Release gate

A version tag or GitHub Release requires all automated checks, mandatory real-device cases, archive checksums, signature/DMG verification, and closure of all release-blocking high-priority issues. Release artifacts stay outside Git and are listed in an immutable manifest.
