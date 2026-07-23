# AUDIT-RECOVERY-20260723-001 — Prehistory retention and cleanup closure

- Status: pass
- Date: 2026-07-23
- Candidate: recovery/clean-Git baseline at main 340251a
- ISSUE: ISSUE-005
- CHG: CHG-20260723-009
- TR: TR-RECOVERY-20260723-002
- Release: `prehistory-2026-07-23`

## Retained evidence

- Frozen legacy Git: 9,658 files, 2.2 GiB, per-file checksum manifest retained.
- Nine unique Assets ZIPs retained locally and on the private Release.
- Seven historical DMGs retained locally and on the private Release.
- Current production assets remain in Git LFS.
- Canonical runtime package remains under SwiftPM resources.

## Remote verification

All 16 Release attachment digests match local files. Four representative
downloads match their manifest hashes; three ZIPs pass extraction tests.

## Cleanup verification

The four owner-approved workspace targets were deleted. Clean `.git` was
installed, local/remote main match, Git/LFS are clean and fsck passes. The
frozen recovery root was not removed. Main Actions run `29987195764` passed
incremental governance, Swift build/tests and package validation before this
audit was proposed.

## Residual risks

- GitHub Free private `main` is governed procedurally, not protected by the
  server; this accepted risk remains ISSUE-013/BC-016.
- Recovery still relies on the owner's GitHub account plus one local frozen
  root. Future offsite replication may add resilience but is not required to
  close the original destructive-cleanup gate.

## Decision

Recovery cleanup is complete and ISSUE-005 may be closed. Later product fixes
must start from clean `main` and must not rewrite this audit.
