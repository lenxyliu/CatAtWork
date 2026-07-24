# TR-GOVERNANCE-20260724-001 — Visual-defect tracking rule

- Status: pass
- Date: 2026-07-24T13:05:01+08:00
- Content-SHA256: 59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8
- Commit/Tree: `codex/visual-defect-tracking-rule` staged candidate
- System: macOS 26.5.2 (25F84), Apple silicon
- Xcode: 26.6 (17F113)
- Swift: 6.3.3 (swiftlang-6.3.3.1.3)
- ISSUE: GitHub #15
- BC: none
- CHG: CHG-20260724-001

## Tested content

The root `AGENTS.md` defect-discovery rule and
`CHG-20260724-001-visual-defect-tracking-rule.md`. The governed-content digest
is unchanged because the rule and its records are Markdown governance
documents, not executable governed content.

## Commands

```sh
git diff --check
python3 Scripts/check_governance.py digest
python3 Scripts/check_governance.py --staged
```

## Passed

- The working diff contains no whitespace errors.
- The governed-content digest is
  `59c533d8130d64397db65e7f1bc9bc87dff4537101fc246e7e79df173ff9d9d8`.
- Staged governance validation accepts the new CHG/TR and the agent-rule
  update.

## Failed

None.

## Skipped

Product build, Swift tests, package validation, and device tests were skipped
because this change only adds Markdown workflow instructions and evidence. It
does not modify executable code, schemas, configuration, production assets,
or package metadata.

## Failure analysis

Not applicable.

## Evidence

The exact command outputs were observed in this Codex task. The GitHub source
of truth is issue `#15`, with defect issues `#9` through `#21` linked as they
were discovered.

## Retrospective

The rule now survives conversation boundaries and requires evidence to be
recorded before analysis continues. A future change to defect lifecycle or
release status still follows the existing repository ISSUE/BC/CHG/TR policy.
