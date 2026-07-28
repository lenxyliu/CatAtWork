from __future__ import annotations

import copy
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_ROOT = REPOSITORY_ROOT / "Scripts"
if str(SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_ROOT))

from assemble_foundation_assets import FoundationBuildError, normalize_material_colors
from compare_foundation_color_only import compare_images
from validate_foundation_color_oracle import (
    material_detail_metrics,
    validate_color_oracle,
)
from validate_foundation_assets import (
    EXPECTED_ACTIONS,
    direction_facing_check,
    projected_b2_contract,
)
from validate_visual_qa import material_labs, sha256_file


FOUNDATION_PATH = REPOSITORY_ROOT / "Config" / "DefaultPet" / "foundation-contract.json"
B2_PATH = (
    REPOSITORY_ROOT
    / "Tests"
    / "Fixtures"
    / "VisualQA"
    / "default-pet-b1-contract.json"
)


class FoundationAssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = json.loads(FOUNDATION_PATH.read_text(encoding="utf-8"))

    def test_scope_and_b2_projection_remain_bounded(self) -> None:
        accepted = json.loads(B2_PATH.read_text(encoding="utf-8"))
        projected = projected_b2_contract(accepted, package_digest="a" * 64)
        actions = {
            action
            for group in projected["actionContracts"]
            for action in group["actions"]
        }
        self.assertEqual(actions, set(EXPECTED_ACTIONS))
        self.assertEqual(projected["baseline"]["expectedFindingIds"], [])
        self.assertEqual(projected["baseline"]["packageDigest"], "a" * 64)

    def test_effect_material_mapping_keeps_groups_distinct(self) -> None:
        image = Image.new("RGBA", (3, 1))
        image.putdata(
            [
                (250, 230, 215, 255),
                (235, 186, 153, 200),
                (82, 38, 21, 160),
            ]
        )
        normalized = normalize_material_colors(
            image,
            material_references=self.foundation["materialReferences"],
        )
        light, warm, dark = list(normalized.getdata())
        self.assertNotEqual(light[:3], warm[:3])
        self.assertNotEqual(warm[:3], dark[:3])
        self.assertEqual([light[3], warm[3], dark[3]], [255, 200, 160])
        self.assertGreater(sum(light[:3]), sum(warm[:3]))
        self.assertGreater(sum(warm[:3]), sum(dark[:3]))
        self.assertEqual(light[:3], (250, 227, 213))
        self.assertEqual(warm[:3], (227, 169, 136))
        self.assertEqual(dark[:3], (65, 23, 10))

    def test_source_effect_oracle_fails_closed_on_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory(prefix="catatwork-foundation-color.") as root:
            directory = Path(root)
            sheet_path = directory / "effect-sheet.png"
            Image.new("RGB", (1, 1), (0, 255, 0)).save(sheet_path)

            frame_path = directory / "effect-frame.png"
            frame = Image.new("RGBA", (30, 3))
            colors = (
                ((248, 220, 205, 255), (252, 230, 217, 255)),
                ((218, 150, 118, 255), (224, 164, 132, 255)),
                ((50, 12, 3, 255), (56, 14, 4, 255)),
            )
            frame.putdata(
                [
                    colors[x // 10][(x + y) % 2]
                    for y in range(3)
                    for x in range(30)
                ]
            )
            frame.save(frame_path)
            source_labs = material_labs(frame)
            source_detail = material_detail_metrics(
                frame,
                frame,
                material_references=self.foundation["materialReferences"],
            )

            foundation = copy.deepcopy(self.foundation)
            oracle = foundation["materialReferences"]["sourceEffectOracle"]
            oracle.update(
                {
                    "sourceSheetSHA256": sha256_file(sheet_path),
                    "sourceFrameSHA256": sha256_file(frame_path),
                    "sourceFrameSize": [30, 3],
                    "visiblePixelCount": 90,
                    "materialLabs": {
                        material: [
                            round(component, 6)
                            for component in source_labs[material]
                        ]
                        for material in ("light", "warm", "dark")
                    },
                }
            )
            oracle["detailRetention"].update(
                {
                    "sourcePairCounts": {
                        material: source_detail[material]["pairCount"]
                        for material in ("light", "warm", "dark")
                    },
                    "sourceGradientRMS": {
                        material: round(
                            float(source_detail[material]["sourceGradientRMS"]),
                            6,
                        )
                        for material in ("light", "warm", "dark")
                    },
                    "minimumAuthoredRatio": 0.5,
                    "maximumAuthoredRatio": 1.5,
                }
            )
            contract_path = directory / "foundation-contract.json"
            contract_path.write_text(
                json.dumps(foundation, ensure_ascii=False, indent=2, sort_keys=True),
                encoding="utf-8",
            )

            passing = validate_color_oracle(
                source_effect_sheet=sheet_path,
                source_effect_frame=frame_path,
                foundation_path=contract_path,
            )
            self.assertEqual(passing["summary"]["decision"], "pass")
            self.assertGreater(passing["changedVisiblePixels"], 0)

            frame.putpixel((0, 0), (249, 225, 212, 255))
            frame.save(frame_path)
            failing = validate_color_oracle(
                source_effect_sheet=sheet_path,
                source_effect_frame=frame_path,
                foundation_path=contract_path,
            )
            self.assertEqual(failing["summary"]["decision"], "fail")
            self.assertIn(
                "source/frame-sha256",
                failing["summary"]["failures"],
            )

    def test_detail_normalization_metadata_fails_closed(self) -> None:
        references = copy.deepcopy(self.foundation["materialReferences"])
        references["normalization"]["detailWeightDenominator"] = 0
        with self.assertRaises(FoundationBuildError):
            normalize_material_colors(
                Image.new("RGBA", (3, 3), (250, 225, 212, 255)),
                material_references=references,
            )

    def test_color_only_comparison_rejects_alpha_changes(self) -> None:
        before = Image.new("RGBA", (2, 1))
        before.putdata([(100, 80, 60, 255), (0, 0, 0, 0)])
        after = Image.new("RGBA", (2, 1))
        after.putdata([(90, 70, 50, 255), (0, 0, 0, 1)])
        comparison = compare_images(
            before,
            after,
            visible_alpha_minimum=12,
        )
        self.assertEqual(comparison["visibleRGBChanges"], 1)
        self.assertEqual(comparison["alphaChanges"], 1)
        self.assertNotEqual(
            comparison["beforeAlphaSHA256"],
            comparison["afterAlphaSHA256"],
        )

    def test_absolute_facing_gate_rejects_mirrored_labels(self) -> None:
        with tempfile.TemporaryDirectory(prefix="catatwork-foundation-direction.") as root:
            candidate = Path(root)
            left = self.direction_fixture(faces_left=True)
            right = self.direction_fixture(faces_left=False)
            left_path = candidate / "left.png"
            right_path = candidate / "right.png"
            left.save(left_path)
            right.save(right_path)
            for action in ("walkLeft", "runLeft", "walkRight", "runRight"):
                directory = candidate / "frames" / action
                directory.mkdir(parents=True)
                source = left_path if action.endswith("Left") else right_path
                for index in range(24):
                    shutil.copyfile(source, directory / f"{index:03d}.png")

            passing = direction_facing_check(
                candidate,
                foundation=self.foundation,
            )
            self.assertTrue(passing["passed"])

            shutil.copyfile(right_path, candidate / "frames" / "runLeft" / "011.png")
            failing = direction_facing_check(
                candidate,
                foundation=self.foundation,
            )
            self.assertFalse(failing["passed"])
            self.assertEqual(
                [(item["action"], item["frame"]) for item in failing["violations"]],
                [("runLeft", 12)],
            )

    @staticmethod
    def direction_fixture(*, faces_left: bool) -> Image.Image:
        image = Image.new("RGBA", (665, 737), (0, 0, 0, 0))
        drawing = ImageDraw.Draw(image)
        drawing.ellipse((180, 100, 485, 410), fill=(248, 224, 207, 255))
        if faces_left:
            drawing.ellipse((155, 105, 235, 195), fill=(82, 38, 21, 255))
        else:
            drawing.ellipse((429, 105, 509, 195), fill=(82, 38, 21, 255))
        return image


if __name__ == "__main__":
    unittest.main()
