# Test and release strategy

## Evidence layers

1. Core unit tests: deterministic reducer, queue, pose, manifest, import limits, physics, layout and cache policy.
2. App integration tests: session reset, AppKit input translation, effect application, asynchronous import and renderer/cache boundaries.
3. Package/asset validation: schema, referenced resources, alpha/dimensions, frame continuity and runtime smoke.
4. Build/release checks: Swift build/typecheck, universal binary, signing, DMG integrity/mount, archive checksums.
5. Real-device acceptance: permissions, 60/120 Hz, displays/Spaces, sleep/wake, three-minute autonomy, pointer regions, grab/throw/single landing, logging and video.

## Freshness

Every TR stores the governed-content SHA-256 calculated by `Scripts/check_governance.py digest`. A final diff that changes governed content invalidates the prior TR. Failures and skips remain in their original immutable record; a rerun creates another TR.

Governed dot-prefixed paths are first-class inputs, including `.gitignore`,
`.gitattributes`, `.githooks/` and `.github/workflows/`. Path normalization
may remove a literal leading `./` or `/`, but must never strip the leading dot
from a repository filename.

## CI toolchain contract

The Swift job runs on `macos-15` with
`DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer`. The job must
print `xcodebuild -version` and `swift --version` before compiling so the
toolchain behind every result remains auditable. The selected Swift compiler
must support the `swift-tools-version` declared by `Package.swift`; changing
the runner or Xcode selection is a strategic release-policy change and
requires a new CHG, ADR, badcase and fresh TR.

Package/asset validation in the hosted job uses Python 3.13 provisioned by
`actions/setup-python` and installs the exact versions listed in
`Scripts/requirements-validation.txt`. The identity step prints Python and
Pillow versions; validation must not rely on packages that happen to be
preinstalled on a runner image.

## Evidence-record lifecycle

An ADR, CHG, TR or audit created only on an unmerged branch is a proposed
record. It may be refined in later commits of the same PR so that its links,
status and final content digest match the actual reviewed change. Earlier
executions are never overwritten: a rerun creates a new TR and the proposed
CHG links both the earlier and later evidence.

A record becomes accepted and immutable when its path exists in protected
`main`. After that boundary, modification or deletion fails governance;
corrections require a new record that links and, where applicable, supersedes
the accepted one. PR CI compares against the exact base SHA. Local staged
validation prefers `refs/remotes/origin/main`, then local `main`, so it applies
the same accepted-record boundary without freezing records that exist only on
the current feature branch.

## Remote enforcement availability

The private GitHub repository permits only squash merge and deletes a feature
branch after merge. Protected `main` must additionally require PRs plus the
`governance` and `swift` checks, and must reject force-push and deletion.

Those server-side controls are a release gate, not a convention. If the
current GitHub plan cannot protect a private repository, local hooks and
passing Actions remain useful evidence but are not equivalent enforcement.
Merging pauses until the owner enables a plan that supports private-repository
protection, changes visibility explicitly, or records a time-bounded exception
through a new CHG/ADR. Automation must never change billing or repository
visibility on the owner's behalf.

## Release gate

No version tag or Release is created until required automatic and device cases pass, all release artifacts have verified checksums, signing/DMG validation succeeds, and every release-blocking high-priority ISSUE is closed.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Established evidence layers, digest freshness and immutable reruns. |
| 2026-07-23 | CHG-20260723-002 | Pinned the hosted Swift job to macOS 15/Xcode 16.4 and required toolchain identity output. |
| 2026-07-23 | CHG-20260723-003 | Corrected dot-path normalization so hooks, workflows and root dotfiles invalidate stale TR evidence. |
| 2026-07-23 | CHG-20260723-004 | Declared Python 3.13 and pinned Pillow for hosted package/asset validation. |
| 2026-07-23 | CHG-20260723-005 | Bound immutability to records accepted by protected main while allowing evidence refinement inside an unmerged PR. |
| 2026-07-23 | CHG-20260723-006 | Applied available squash-only merge settings and made private-repository protection availability an explicit blocking gate. |
