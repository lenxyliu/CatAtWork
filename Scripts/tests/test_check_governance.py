from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "check_governance.py"
REPOSITORY_ROOT = MODULE_PATH.parents[1]
SPEC = importlib.util.spec_from_file_location("check_governance", MODULE_PATH)
assert SPEC and SPEC.loader
governance = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = governance
SPEC.loader.exec_module(governance)


class GovernanceFixtureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.write("Sources/App.swift", "let answer = 42\n")
        self.write("docs/issues/ISSUE-REGISTER.md", "| ISSUE-001 | open | fixture |\n")
        self.write("docs/issues/badcases/BC-001.md", self.badcase())
        self.write("docs/design/SYSTEM.md", "# Design\n\nCHG-20260723-999\n")
        self.write("docs/adr/ADR-0999-fixture.md", "# ADR-0999\n\nCHG-20260723-999\n")
        self.write("docs/changes/CHG-20260723-999-fixture.md", self.change())
        self.write("docs/test-runs/TR-FIXTURE.md", self.render_test_run("placeholder"))
        digest = governance.content_digest(self.root)
        self.write("docs/test-runs/TR-FIXTURE.md", self.render_test_run(digest))

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write(self, relative: str, content: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    @staticmethod
    def badcase() -> str:
        return """# BC-001

- Status: open
- ISSUE: ISSUE-001
- First observed: 2026-07-23
- Affected versions: fixture
- Fixed versions: none
- Regression test: fixture
- Automated evidence: fixture
- Device evidence: not applicable

## Preconditions
## Reproduction
## Expected
## Actual
## Root cause
## Impact
## Status timeline
"""

    @staticmethod
    def change() -> str:
        return """# CHG-20260723-999

- Status: complete
- Change-Type: fix
- Strategic-Change: yes
- Owner: fixture
- Created: 2026-07-23
- ISSUE: ISSUE-001
- BC: BC-001
- ADR: ADR-0999
- Design: SYSTEM
- TR: TR-FIXTURE

## Purpose
## Before: badcase and risk
## Design impact
## Changes
## Compatibility
## Test evidence
## Rollback
## Revision log
"""

    @staticmethod
    def render_test_run(digest: str, status: str = "pass") -> str:
        return f"""# TR-FIXTURE

- Status: {status}
- Date: 2026-07-23T00:00:00Z
- Content-SHA256: {digest}
- Commit/Tree: fixture
- System: fixture
- Xcode: fixture
- Swift: fixture
- ISSUE: ISSUE-001
- BC: BC-001
- CHG: CHG-20260723-999

## Tested content
## Commands
## Passed
## Failed
## Skipped
## Failure analysis
## Evidence
## Retrospective
"""

    def compliant_changes(self):
        return [
            governance.Change("A", "Sources/App.swift"),
            governance.Change("A", "docs/issues/badcases/BC-001.md"),
            governance.Change("A", "docs/design/SYSTEM.md"),
            governance.Change("A", "docs/adr/ADR-0999-fixture.md"),
            governance.Change("A", "docs/changes/CHG-20260723-999-fixture.md"),
            governance.Change("A", "docs/test-runs/TR-FIXTURE.md"),
        ]

    def test_complete_compliant_change_passes(self):
        self.assertEqual(governance.validate_repository(self.root, self.compliant_changes()), [])

    def test_missing_change_record_fails(self):
        errors = governance.validate_repository(self.root, [governance.Change("M", "Sources/App.swift")])
        self.assertTrue(any("without a new CHG" in error for error in errors))

    def test_missing_badcase_fails(self):
        (self.root / "docs/issues/badcases/BC-001.md").unlink()
        errors = governance.validate_repository(self.root, self.compliant_changes())
        self.assertTrue(any("badcase does not exist" in error for error in errors))

    def test_strategic_change_without_design_diff_fails(self):
        changes = [change for change in self.compliant_changes() if not change.path.startswith("docs/design/")]
        errors = governance.validate_repository(self.root, changes)
        self.assertTrue(any("design-document update" in error for error in errors))

    def test_failed_test_record_fails(self):
        digest = governance.content_digest(self.root)
        self.write("docs/test-runs/TR-FIXTURE.md", self.render_test_run(digest, status="fail"))
        errors = governance.validate_repository(self.root, self.compliant_changes())
        self.assertTrue(any("no referenced passing TR" in error for error in errors))

    def test_stale_content_digest_fails(self):
        self.write("Sources/App.swift", "let answer = 43\n")
        errors = governance.validate_repository(self.root, self.compliant_changes())
        self.assertTrue(any("no referenced passing TR" in error for error in errors))

    def test_dot_prefixed_governance_paths_are_preserved(self):
        self.assertEqual(
            governance.normalize("./.github/workflows/ci.yml"),
            ".github/workflows/ci.yml",
        )
        self.assertTrue(governance.is_governed(".github/workflows/ci.yml"))
        self.assertTrue(governance.is_governed(".githooks/pre-push"))
        self.assertTrue(governance.is_governed(".gitignore"))

    def test_dot_prefixed_change_invalidates_digest(self):
        before = governance.content_digest(self.root)
        self.write(".github/workflows/ci.yml", "name: first\n")
        after_create = governance.content_digest(self.root)
        self.write(".github/workflows/ci.yml", "name: second\n")
        after_update = governance.content_digest(self.root)
        self.assertNotEqual(before, after_create)
        self.assertNotEqual(after_create, after_update)

    def test_trivial_label_rejects_executable_change(self):
        errors = governance.validate_repository(
            self.root, [governance.Change("M", "Sources/App.swift")], trivial=True
        )
        self.assertTrue(any("trivial is illegal" in error for error in errors))

    def test_trivial_label_accepts_markdown_only(self):
        errors = governance.validate_repository(
            self.root, [governance.Change("M", "README.md")], trivial=True
        )
        self.assertEqual(errors, [])

    def test_record_already_in_protected_base_is_immutable(self):
        path = "docs/changes/CHG-20260723-999-fixture.md"
        errors = governance.validate_repository(
            self.root,
            [governance.Change("M", path)],
            protected_immutable={path},
        )
        self.assertTrue(any("immutable record" in error for error in errors))

    def test_unmerged_branch_record_can_be_refined(self):
        path = "docs/test-runs/TR-FIXTURE.md"
        errors = governance.validate_repository(
            self.root,
            [governance.Change("M", path)],
            protected_immutable=set(),
        )
        self.assertFalse(any("immutable record" in error for error in errors))


class WorkflowContractTests(unittest.TestCase):
    def test_main_push_validates_only_the_pushed_diff(self):
        workflow = (REPOSITORY_ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertIn(
            'python3 Scripts/check_governance.py --base "${{ github.event.before }}"',
            workflow,
        )
        self.assertNotIn("run: python3 Scripts/check_governance.py --all", workflow)


if __name__ == "__main__":
    unittest.main()
