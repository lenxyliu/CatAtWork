# Changelog

All user-visible changes are summarized here. Implementation and test evidence lives in the linked CHG, ISSUE, BC, and TR records.

## Unreleased

- Added canonical format-2 `.catpet` support with fixed world scale/canvas,
  anatomical root and support anchors, identity/pose/color/component
  metadata, and deterministic source-to-atlas validation. Existing format-1
  packages remain readable and are never silently upgraded
  ([CHG-20260726-005](docs/changes/CHG-20260726-005-canonical-pet-asset-contract.md)).
- Package import, validation and texture decoding no longer run on the UI
  thread. Archive helper output, processing time and package expansion are
  bounded; repeated frames use a 128 MiB session cache, and stale imports or
  textures cannot replace the current pet
  ([CHG-20260723-012](docs/changes/CHG-20260723-012-background-asset-io.md)).
- Unified custom `.catpet` behavior: missing actions now use documented
  semantic fallbacks or stay unavailable, custom poses and `nextAnimation`
  are honored, pixel density no longer changes desktop size, pet switching
  starts a fresh session, and transparent margins no longer intercept input
  ([CHG-20260723-011](docs/changes/CHG-20260723-011-pet-package-session-contract.md)).
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
