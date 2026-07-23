# TR-GOVERNANCE-20260723-001 — Governance checker fixtures

- Status: pass
- Date: 2026-07-23T11:02:00+08:00
- Content-SHA256: f65994c801ab82bdf44dadba1e8fb53e1b78864006457c57d00afe8e0911ab10
- Commit/Tree: unborn `main`; pre-clean-baseline working tree
- System: macOS 26.5.2 (25F84), Apple silicon
- Xcode: 26.6 (17F113)
- Swift: 6.3.3 (swiftlang-6.3.3.1.3); Python 3.9 standard library runner
- ISSUE: ISSUE-006
- BC: BC-009
- CHG: CHG-20260723-001

## Tested content

`Scripts/check_governance.py`, its fixture suite, hook/workflow governance inputs, and the current governed-content digest.

## Commands

```sh
python3 -B -m unittest discover -s Scripts/tests -p 'test_*.py' -v
python3 -B Scripts/check_governance.py digest
```

## Passed

Eight fixtures passed: complete compliant change, missing CHG rejection, missing badcase rejection, missing strategic design diff rejection, failed TR rejection, stale digest rejection, invalid executable trivial-label rejection, and Markdown-only trivial acceptance. Digest output matched this record.

## Failed

None in the final fixture execution.

## Skipped

GitHub-hosted execution is pending creation/push of the private repository. Branch-protection behavior is therefore not claimed here.

## Failure analysis

The first local import of the fixture module did not register the dynamic module in `sys.modules`, which Python 3.9 dataclasses require. The test harness was corrected and the whole suite rerun. A separate initial `py_compile` attempt also tried to write bytecode outside the sandbox; final commands use `-B`.

## Evidence

Final unittest output in this Codex task: 8 tests, 0 failures/errors, runtime 0.137 seconds. Governed digest: `f65994c801ab82bdf44dadba1e8fb53e1b78864006457c57d00afe8e0911ab10`.

## Retrospective

The gate now proves its most important rejection paths locally. CI remains the authority after GitHub setup. Future changes to the checker require new negative fixtures and a new TR; this record must not be edited after baseline merge.

