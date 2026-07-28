from __future__ import annotations

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

from assemble_foundation_assets import normalize_material_colors
from validate_foundation_assets import (
    EXPECTED_ACTIONS,
    direction_facing_check,
    projected_b2_contract,
)


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

    def test_fixed_material_mapping_keeps_canonical_groups_distinct(self) -> None:
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
