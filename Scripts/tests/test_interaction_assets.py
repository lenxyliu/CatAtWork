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

from assemble_interaction_assets import (
    EXPECTED_ACTIONS,
    expanded_pose_order,
)
from validate_interaction_assets import (
    SCAN_ACTIONS,
    direction_check,
    projected_b2_contract,
)


INTERACTION_PATH = (
    REPOSITORY_ROOT
    / "Config"
    / "DefaultPet"
    / "interaction-contract.json"
)
B2_PATH = (
    REPOSITORY_ROOT
    / "Tests"
    / "Fixtures"
    / "VisualQA"
    / "default-pet-b1-contract.json"
)


class InteractionAssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.interaction = json.loads(
            INTERACTION_PATH.read_text(encoding="utf-8")
        )

    def test_scope_and_b2_projection_remain_bounded(self) -> None:
        self.assertEqual(
            tuple(self.interaction["scope"]["actions"]),
            EXPECTED_ACTIONS,
        )
        self.assertEqual(self.interaction["scope"]["frameCount"], 336)
        accepted = json.loads(B2_PATH.read_text(encoding="utf-8"))
        projected = projected_b2_contract(
            accepted,
            package_digest="a" * 64,
        )
        actions = {
            action
            for group in projected["actionContracts"]
            for action in group["actions"]
        }
        self.assertEqual(actions, set(SCAN_ACTIONS))
        self.assertEqual(
            projected["baseline"]["expectedFindingIds"],
            [],
        )

    def test_pose_expansion_is_exactly_twenty_two_inbetweens(self) -> None:
        for action in self.interaction["actions"]:
            expanded = expanded_pose_order(action["poseOrder"])
            self.assertEqual(len(expanded), 22)
            self.assertEqual(expanded[0], action["poseOrder"][0])
            self.assertEqual(expanded[-1], action["poseOrder"][-1])

    def test_waiting_holds_open_between_a_short_blink(self) -> None:
        waiting = next(
            action
            for action in self.interaction["actions"]
            if action["id"] == "waiting"
        )
        expanded = expanded_pose_order(waiting["poseOrder"])
        self.assertEqual(waiting["fps"], 7)
        self.assertEqual(
            expanded,
            [
                0, 0, 0, 0, 0, 0, 0, 0,
                1, 2, 3, 2, 1,
                0, 0, 0, 0, 0, 0, 0, 0, 0,
            ],
        )
        self.assertLess(5 / waiting["fps"], 1.0)
        self.assertGreater(19 / waiting["fps"], 2.5)

    def test_direction_gate_requires_right_base_and_exact_left_mirror(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="catatwork-interaction-direction."
        ) as root:
            candidate = Path(root)
            build_actions = {}
            idle = self.direction_fixture(head_x=300)
            for action in ("idle", *self.interaction[
                "interactionDirectionPolicy"
            ]["actions"]):
                directory = candidate / "frames" / action
                directory.mkdir(parents=True)
                frames = []
                source_pose = self.interaction[
                    "interactionDirectionPolicy"
                ]["actions"].get(action, {}).get("sourcePose")
                for index in range(24):
                    image = (
                        self.direction_fixture(head_x=320)
                        if action != "idle" and index == 12
                        else idle
                    )
                    image.save(directory / f"{index:03d}.png")
                    frames.append(
                        {
                            "sourcePose": (
                                source_pose if index == 12 else None
                            )
                        }
                    )
                if action != "idle":
                    build_actions[action] = frames
            runtime = candidate / "PetWindowController.swift"
            runtime.write_text(
                "interactionFacesLeft = lockedLeft\n"
                "flipHorizontally: interactionDirectionUntil > "
                "CACurrentMediaTime() && interactionFacesLeft\n",
                encoding="utf-8",
            )
            passing = direction_check(
                candidate,
                build_report={"actions": build_actions},
                interaction=self.interaction,
                runtime_source=runtime,
            )
            self.assertTrue(passing["passed"])

            action = next(iter(build_actions))
            self.direction_fixture(head_x=280).save(
                candidate / "frames" / action / "012.png"
            )
            failing = direction_check(
                candidate,
                build_report={"actions": build_actions},
                interaction=self.interaction,
                runtime_source=runtime,
            )
            self.assertFalse(failing["passed"])

    @staticmethod
    def direction_fixture(*, head_x: int) -> Image.Image:
        image = Image.new("RGBA", (665, 737), (0, 0, 0, 0))
        drawing = ImageDraw.Draw(image)
        drawing.ellipse((230, 260, 430, 537), fill=(244, 220, 204, 255))
        drawing.ellipse(
            (head_x - 65, 150, head_x + 65, 300),
            fill=(82, 38, 21, 255),
        )
        drawing.rectangle(
            (min(head_x, 330), 275, max(head_x, 330), 320),
            fill=(244, 220, 204, 255),
        )
        return image


if __name__ == "__main__":
    unittest.main()
