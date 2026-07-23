# Test and release strategy

## Evidence layers

1. Core unit tests: deterministic reducer, queue, pose, manifest, import limits, physics, layout and cache policy.
2. App integration tests: session reset, AppKit input translation, effect application, asynchronous import and renderer/cache boundaries.
3. Package/asset validation: schema, referenced resources, alpha/dimensions, frame continuity and runtime smoke.
4. Build/release checks: Swift build/typecheck, universal binary, signing, DMG integrity/mount, archive checksums.
5. Real-device acceptance: permissions, 60/120 Hz, displays/Spaces, sleep/wake, three-minute autonomy, pointer regions, grab/throw/single landing, logging and video.

## Freshness

Every TR stores the governed-content SHA-256 calculated by `Scripts/check_governance.py digest`. A final diff that changes governed content invalidates the prior TR. Failures and skips remain in their original immutable record; a rerun creates another TR.

## Release gate

No version tag or Release is created until required automatic and device cases pass, all release artifacts have verified checksums, signing/DMG validation succeeds, and every release-blocking high-priority ISSUE is closed.

## Revision log

| Date | CHG | Revision |
| --- | --- | --- |
| 2026-07-23 | CHG-20260723-001 | Established evidence layers, digest freshness and immutable reruns. |

