# TR-BASELINE-20260723-001 — Initial sandboxed Swift test attempt

- Status: fail
- Date: 2026-07-23T10:54:00+08:00
- Content-SHA256: f65994c801ab82bdf44dadba1e8fb53e1b78864006457c57d00afe8e0911ab10
- Commit/Tree: unborn `main`; pre-clean-baseline working tree
- System: macOS 26.5.2 (25F84), Apple silicon
- Xcode: 26.6 (17F113)
- Swift: 6.3.3 (swiftlang-6.3.3.1.3)
- ISSUE: ISSUE-006
- BC: BC-009
- CHG: CHG-20260723-001

## Tested content

Attempted the existing 36-test Swift baseline with the final governed-content digest shown above.

## Commands

```sh
swift test
```

## Passed

None; the package manifest could not be compiled in the restricted process.

## Failed

Swift/Clang tried to write `/Users/oops/.cache/clang/ModuleCache` and failed with `Operation not permitted`, followed by “unable to load standard library”. Exit 1.

## Skipped

All 36 tests were not started.

## Failure analysis

This was a test-environment sandbox failure, not a source/test assertion failure. SwiftPM's user-level caches were also unavailable. The permitted response is a new execution outside the restrictive sandbox, not editing this failure into a pass.

## Evidence

Codex task command output for the 2026-07-23 initial `swift test` execution.

## Retrospective

Swift commands that require compiler caches should be run with the repository-scoped approved `swift test`/`swift build` capability or with an explicitly writable cache configuration. The failure remains recorded to distinguish infrastructure from product regressions.

