# Changelog

All user-visible changes are summarized here. Implementation and test evidence lives in the linked CHG, ISSUE, BC, and TR records.

## Unreleased

- Fixed mixed-priority action queues so every selected action receives legal
  pose transitions from the pet's actual current pose, without another action
  splitting the transition from its target
  ([CHG-20260723-010](docs/changes/CHG-20260723-010-action-dequeue-routing.md)).
- Repository recovery and traceability baseline is complete: current assets
  use Git LFS, prehistory is preserved in a checksum-verified private Release,
  and disposable local build/history duplicates have been removed.
- No application behavior change is claimed by the recovery work.

## Historical baseline — 2026-07-23

- The pre-governance state is frozen in `ISSUE-CLASSIFICATION.md` and `COMPLETION-AUDIT.md`. Those files are evidence snapshots and are no longer edited.
