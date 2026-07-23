# CHG-20260723-003 — Include dot-prefixed paths in freshness digests

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: repository maintainers
- Created: 2026-07-23
- ISSUE: ISSUE-008
- BC: BC-011
- ADR: ADR-0005
- Design: TEST-AND-RELEASE
- TR: TR-CI-20260723-001

## Purpose

Ensure changes to workflows, hooks and root governance dotfiles invalidate
older test evidence.

## Before: badcase and risk

Changing `.github/workflows/ci.yml` left the governed digest at
`62892881033a2331961372ddcfa57bc97041f525e94f63516d3e58f007227390`.
The gate could therefore accept a TR created before an executable governance
change.

## Design impact

The freshness contract now explicitly includes dot-prefixed repository paths
and defines safe normalization semantics. ADR-0005 makes that hashing
boundary immutable.

## Changes

- Replace character-set `lstrip("./")` with literal relative-prefix removal.
- Preserve `.github`, `.githooks`, `.gitignore` and `.gitattributes` names.
- Add regression fixtures for classification and digest create/update
  invalidation.

## Compatibility

No application behavior changes. Corrected digests intentionally differ from
older values because previously omitted governed files are now included.

## Test evidence

TR-CI-20260723-001 must record all 10 governance fixtures and a fresh digest
that changes when the CI workflow changes.

## Rollback

Do not restore `lstrip("./")`. If path normalization must change again,
supersede ADR-0005 with a new ADR/CHG and prove every governed dotpath remains
in the digest.

## Revision log

- 2026-07-23: opened after the CI runner change failed to alter the governed
  digest.
- 2026-07-23: all 10 governance fixtures passed; corrected governed digest is
  `b7d463ec4d7c7800b17a6a8dcb04250da0cc7e5341d26d7096c34ed8848e7371`.
