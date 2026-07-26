from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "validate_visual_qa.py"
REPOSITORY_ROOT = MODULE_PATH.parents[1]
FIXTURE_ROOT = REPOSITORY_ROOT / "Tests" / "Fixtures" / "VisualQA"
SPEC = importlib.util.spec_from_file_location("validate_visual_qa", MODULE_PATH)
assert SPEC and SPEC.loader
visual_qa = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = visual_qa
SPEC.loader.exec_module(visual_qa)


def fixture_metadata() -> dict:
    return {
        "package": {
            "id": "fixture",
            "assetVersion": "1",
            "packageDigest": "0" * 64,
            "actionCount": 1,
            "frameCount": 3,
        },
        "input_digests": {
            "manifest": "1" * 64,
            "package": "0" * 64,
            "source": "2" * 64,
            "contract": "3" * 64,
            "supplemental": "4" * 64,
        },
        "tool_versions": {
            "visualQa": "fixture",
            "python": "fixture",
            "pillow": "fixture",
        },
    }


class VisualQAFixtureTests(unittest.TestCase):
    def evaluate(
        self,
        *,
        mode: str,
        observations: list[dict],
        expected: list[str] | None = None,
        waivers: list[dict] | None = None,
    ) -> dict:
        metadata = fixture_metadata()
        return visual_qa.evaluate_observations(
            mode=mode,
            observations=observations,
            expected_failure_ids=expected or [],
            waivers=waivers or [],
            package=metadata["package"],
            input_digests=metadata["input_digests"],
            tool_versions=metadata["tool_versions"],
        )

    def test_every_negative_fixture_fails_for_its_intended_reason(self) -> None:
        paths = sorted((FIXTURE_ROOT / "negative").glob("*.json"))
        self.assertEqual(len(paths), 15)
        observed_families = set()
        for path in paths:
            fixture = json.loads(path.read_text(encoding="utf-8"))
            item = fixture["observation"]
            report = self.evaluate(mode="release", observations=[item])
            self.assertEqual(report["decision"], "fail", path.name)
            self.assertEqual(
                [finding["findingId"] for finding in report["findings"]],
                [fixture["expectedFindingId"]],
                path.name,
            )
            self.assertEqual(report["findings"][0]["violations"][0]["observationId"], item["observationId"])
            observed_families.add(item["family"])
        self.assertEqual(
            observed_families,
            {
                "sourceAtlasRoundTrip",
                "canonicalIdentity",
                "rootSupport",
                "materialColor",
                "connectedComponents",
                "edgeClearance",
                "adjacentContinuity",
                "batchSeamContinuity",
                "loopSeamContinuity",
                "secondDifference",
                "endpointPose",
                "locomotion",
                "cadence",
                "renderSnapshot",
                "gazeBodyOrthogonality",
            },
        )

    def test_clean_fixture_release_passes(self) -> None:
        fixture = json.loads((FIXTURE_ROOT / "clean-observations.json").read_text(encoding="utf-8"))
        report = self.evaluate(mode="release", observations=fixture["observations"])
        self.assertEqual(report["decision"], "pass")
        self.assertEqual(report["summary"]["errorCount"], 0)
        self.assertEqual(report["summary"]["unwaivedWarningCount"], 0)

    def test_baseline_requires_exact_known_failure_set(self) -> None:
        item = json.loads(
            (FIXTURE_ROOT / "negative" / "material-color.json").read_text(encoding="utf-8")
        )["observation"]
        finding_id = item["findingId"]
        exact = self.evaluate(mode="baseline", observations=[item], expected=[finding_id])
        self.assertEqual(exact["decision"], "pass")
        missing = self.evaluate(mode="baseline", observations=[], expected=[finding_id])
        self.assertEqual(missing["decision"], "fail")
        self.assertEqual(missing["baselineComparison"]["missingFindingIds"], [finding_id])
        additional = self.evaluate(mode="baseline", observations=[item], expected=[])
        self.assertEqual(additional["decision"], "fail")
        self.assertEqual(additional["baselineComparison"]["newFindingIds"], [finding_id])

    def test_release_has_no_implicit_warning_escape(self) -> None:
        item = {
            "observationId": "fixture/warning",
            "findingId": "fixture/warning",
            "family": "fixture",
            "metric": "value",
            "value": 2,
            "comparison": "lte",
            "threshold": 1,
            "thresholdSource": "fixture",
            "severity": "warning",
            "action": "fixture",
            "frames": [1],
        }
        unwaived = self.evaluate(mode="release", observations=[item])
        self.assertEqual(unwaived["decision"], "fail")
        self.assertEqual(unwaived["summary"]["unwaivedWarningCount"], 1)
        waiver = {
            "id": "WAIVER-FIXTURE-001",
            "issue": "ISSUE-999",
            "rationale": "Exercise explicit warning waiver behavior.",
            "owner": "fixture-owner",
            "affectedActions": ["fixture"],
            "affectedFrames": ["fixture:1"],
            "expiryDate": "2099-12-31",
        }
        item["waiverId"] = waiver["id"]
        waived = self.evaluate(mode="release", observations=[item], waivers=[waiver])
        self.assertEqual(waived["decision"], "pass")
        self.assertEqual(waived["summary"]["waivedFindingCount"], 1)

    def test_waivers_require_all_identity_and_scope_fields(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing required fields"):
            visual_qa.validate_waivers([{"id": "WAIVER-INCOMPLETE"}])
        expired = {
            "id": "WAIVER-EXPIRED",
            "issue": "ISSUE-999",
            "rationale": "Expired fixture.",
            "owner": "fixture-owner",
            "affectedActions": ["fixture"],
            "affectedFrames": ["fixture:1"],
            "expiryDate": "2000-01-01",
        }
        with self.assertRaisesRegex(ValueError, "expired"):
            visual_qa.validate_waivers([expired])

    def test_errors_cannot_be_waived(self) -> None:
        item = json.loads(
            (FIXTURE_ROOT / "negative" / "edge-clearance.json").read_text(encoding="utf-8")
        )["observation"]
        item["waiverId"] = "WAIVER-FIXTURE-ERROR"
        waiver = {
            "id": "WAIVER-FIXTURE-ERROR",
            "issue": "ISSUE-999",
            "rationale": "Errors remain non-waivable.",
            "owner": "fixture-owner",
            "affectedActions": ["fixture"],
            "affectedFrames": ["fixture:1"],
            "expiryDate": "2099-12-31",
        }
        with self.assertRaisesRegex(ValueError, "cannot be waived"):
            self.evaluate(mode="release", observations=[item], waivers=[waiver])

    def test_normalized_output_is_byte_identical_for_reordered_input(self) -> None:
        fixture = json.loads((FIXTURE_ROOT / "clean-observations.json").read_text(encoding="utf-8"))
        forward = self.evaluate(mode="release", observations=fixture["observations"])
        reverse = self.evaluate(mode="release", observations=list(reversed(fixture["observations"])))
        self.assertEqual(
            visual_qa.canonical_bytes(forward, pretty=True),
            visual_qa.canonical_bytes(reverse, pretty=True),
        )

    def test_action_contracts_cover_every_manifest_action_once(self) -> None:
        manifest = json.loads(
            (
                REPOSITORY_ROOT
                / "Sources"
                / "CatAtWork"
                / "Resources"
                / "DefaultPet.catpet"
                / "manifest.json"
            ).read_text(encoding="utf-8")
        )
        contract = json.loads(
            (FIXTURE_ROOT / "default-pet-b1-contract.json").read_text(encoding="utf-8")
        )
        actions = [item["id"] for item in manifest["animations"]]
        compiled = visual_qa.compile_action_contracts(contract, actions)
        self.assertEqual(set(compiled), set(actions))
        for action in actions:
            semantic = compiled[action]
            self.assertIn("squashStretch", semantic)
            self.assertIn("airborneMovement", semantic)
            self.assertIn("supportPhases", semantic)
            self.assertIn("allowedDisconnectedComponents", semantic)

    def test_report_schema_requires_identity_metrics_threshold_and_waiver_fields(self) -> None:
        schema = json.loads(
            (REPOSITORY_ROOT / "Schemas" / "visual-qa-report-v1.schema.json").read_text(
                encoding="utf-8"
            )
        )
        required = set(schema["required"])
        self.assertTrue(
            {
                "contentDigest",
                "toolVersions",
                "package",
                "findings",
                "observations",
                "waivers",
            }
            <= required
        )
        observation_required = set(schema["$defs"]["observation"]["required"])
        self.assertTrue(
            {
                "observationId",
                "findingId",
                "family",
                "metric",
                "value",
                "threshold",
                "thresholdSource",
            }
            <= observation_required
        )
        waiver_required = set(schema["$defs"]["waiver"]["required"])
        self.assertEqual(
            waiver_required,
            {
                "id",
                "issue",
                "rationale",
                "owner",
                "affectedActions",
                "affectedFrames",
                "expiryDate",
            },
        )


if __name__ == "__main__":
    unittest.main()
