# CHG-20260723-009 — Finalize verified recovery cleanup

- Status: complete
- Change-Type: governance
- Strategic-Change: no
- Owner: lenxyliu
- Created: 2026-07-23
- ISSUE: ISSUE-005
- BC: BC-008
- ADR: ADR-0002, ADR-0003
- Design: ASSET-PIPELINE
- TR: TR-RECOVERY-20260723-002

## Purpose

Close the history-recovery gate after remote round-trip verification and
record the exact owner-authorized local cleanup.

## Before: badcase and risk

The manifest still described remote upload and cleanup as pending even though
the Release had been verified. The workspace retained a 2.2 GiB legacy Git
duplicate, two regenerable build directories and a duplicate 77 MiB runtime
package.

## Design impact

No asset-retention policy changes. This executes ADR-0002/ADR-0003: keep one
frozen legacy Git backup plus immutable remote prehistory, while the product
workspace contains only clean Git/LFS history and the canonical runtime
package.

## Changes

- Verify all 16 remote attachment digests and four representative downloads.
- Confirm workspace legacy Git content matches the frozen backup.
- Delete the approved legacy `.git`, `.build`, `Build` and duplicate
  `Resources/DefaultPets`.
- Install the clean Git database at the normal workspace `.git` path.
- Verify main/remote identity, Git/LFS cleanliness and object integrity.
- Update ISSUE-005, BC-008, the recovery manifest and immutable audit.

## Compatibility

No source or production asset was removed. Swift rebuilds `.build`; release
scripts rebuild `Build`. The only deleted pet package was byte-identical to
the retained SwiftPM runtime package.

## Test evidence

TR-RECOVERY-20260723-002 records remote digests/downloads, pre-delete
equivalence, exact sizes and post-cleanup Git/LFS/fsck results.

## Rollback

Restore old Git history from
`/Users/oops/Documents/CatAtWork-Recovery-2026-07-23/legacy-git` or the
checksum-verified Release archives. Regenerate build directories with the
versioned scripts; copy the retained runtime package only if a legacy external
layout is explicitly required.

## Revision log

- 2026-07-23: cleanup executed after explicit owner approval and remote
  round-trip verification.
