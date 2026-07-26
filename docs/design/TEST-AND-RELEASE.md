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

A record becomes accepted and immutable when its path exists in canonical
`main`, regardless of whether the host can enforce branch protection. After
that boundary, modification or deletion fails governance;
corrections require a new record that links and, where applicable, supersedes
the accepted one. PR CI compares against the exact base SHA. Local staged
validation prefers `refs/remotes/origin/main`, then local `main`, so it applies
the same accepted-record boundary without freezing records that exist only on
the current feature branch.

## Remote enforcement availability

The private GitHub repository permits only squash merge and deletes a feature
branch after merge. GitHub Free cannot enforce required PRs/checks,
force-push prevention or deletion prevention for this private repository.
The owner explicitly declines a paid plan and accepts that limitation.

The procedural fallback requires all work to use PRs, manual confirmation that
`governance` and `swift` passed on the final head, and squash merge. Local
hooks and passing Actions are useful evidence but are not equivalent to server
enforcement. Automation must never claim `main` is protected or change billing
or visibility. ISSUE-013/BC-016 remain `wont-fix` so the accepted risk stays
visible.

## Push-to-main validation

PR checks compare the final head against the exact PR base SHA. A push to
`main` compares the new commit against `github.event.before`; it must not run
the one-time `--all` baseline mode. Treating the whole repository as newly
added would revalidate accepted immutable history against the latest digest
and would require every strategic CHG to appear in every design document.
The `--all` mode is reserved for establishing a new repository baseline.

## Release gate

No version tag or Release is created until required automatic and device cases pass, all release artifacts have verified checksums, signing/DMG validation succeeds, and every release-blocking high-priority ISSUE is closed.

## Deterministic visual-QA gate

Visual acceptance uses the versioned report and mode policy established by
ADR-0015:

- normalized report bytes depend only on input content, reviewed contracts
  and declared tool versions; paths, timestamps and host-specific ordering are
  excluded;
- every finding carries stable package/action/frame identity, metric and
  observed values, threshold value/source and optional validated waiver ID;
- baseline mode requires exact equality with the reviewed known-failure set
  for the same package and supplemental-evidence content;
- release mode permits zero errors and zero unwaived warnings; an error cannot
  be waived and missing required evidence is an error;
- waivers name an Issue, rationale, owner, affected actions/frames and expiry
  date, and never silently broaden their scope;
- action contracts explicitly describe squash/stretch budgets, airborne
  movement, support phases and allowed disconnected components.

The gate covers source/atlas round-trip, identity proxies, root/support,
material color, connected components, edge clearance, adjacent/batch/loop
seams, endpoint poses, locomotion/cadence/snapshot evidence and gaze/body
orthogonality. Negative fixtures and byte-determinism checks are mandatory.
Generated reports and previews remain outside Git; reviewed contracts and
synthetic test fixtures are governed source.

## Canonical asset-contract gate

Format-2 packaging and import additionally require governed synthetic
fixtures that prove:

- tail/fur or silhouette-bound changes do not move the authored root, pivot
  or package world scale;
- all source RGBA/alpha bytes survive atlas packing without resize,
  resampling or color conversion;
- repeated equal inputs produce byte-identical manifest and atlas trees;
- invalid canvas/safe margin, root/support anchor, pose/signature, color,
  identity rig, digest or component metadata fails closed;
- a secondary component is rejected unless one complete reviewed exception
  matches its exact content scope;
- format 1 remains readable, legacy authoring requires explicit
  `--legacy-v1`, and the governed production package is unchanged.

The full Python suite, fresh-path Swift suite and hosted Swift job run these
fixtures. Until B4 creates a reviewed format-2 production package, CI also
runs the unchanged B2 baseline/release oracle against asset `2026.07.23.6`;
baseline must match exactly and release must continue to reject it.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Established evidence layers, digest freshness and immutable reruns. |
| 2026-07-23 | CHG-20260723-002 | Pinned the hosted Swift job to macOS 15/Xcode 16.4 and required toolchain identity output. |
| 2026-07-23 | CHG-20260723-003 | Corrected dot-path normalization so hooks, workflows and root dotfiles invalidate stale TR evidence. |
| 2026-07-23 | CHG-20260723-004 | Declared Python 3.13 and pinned Pillow for hosted package/asset validation. |
| 2026-07-23 | CHG-20260723-005 | Bound immutability to records accepted by protected main while allowing evidence refinement inside an unmerged PR. |
| 2026-07-23 | CHG-20260723-006 | Applied available squash-only merge settings and made private-repository protection availability an explicit blocking gate. |
| 2026-07-23 | CHG-20260723-007 | Recorded the owner's permanent no-paid-plan decision and procedural unprotected-main policy. |
| 2026-07-23 | CHG-20260723-008 | Changed push-to-main governance from full-baseline validation to the exact pushed diff. |
| 2026-07-26 | CHG-20260726-003 | Added deterministic visual-QA report, baseline/release decision and waiver policy. |
| 2026-07-26 | CHG-20260726-005 | Added canonical format-2 source/package, fail-closed negative, deterministic round-trip and legacy non-rewrite gates. |
