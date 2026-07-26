from __future__ import annotations

import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from Scripts.canonical_asset_contract import (
    CanonicalAssetContractError,
    build_canonical_package,
    canonical_rgba_digest,
    validate_canonical_package,
)


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
FIXTURE = (
    REPOSITORY_ROOT
    / "Tests"
    / "Fixtures"
    / "CanonicalAssetContract"
    / "valid-spec.json"
)
DEFAULT_PACKAGE = (
    REPOSITORY_ROOT
    / "Sources"
    / "CatAtWork"
    / "Resources"
    / "DefaultPet.catpet"
)


def tree_digest(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
        digest.update(path.relative_to(root).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
    return digest.hexdigest()


class CanonicalAssetContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="catatwork-b3-fixture.")
        self.root = Path(self.temporary.name)
        self.assets = self.root / "Assets"
        self.frames = self.assets / "frames" / "idle"
        self.frames.mkdir(parents=True)
        self.spec = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.write_spec()
        self.write_valid_frames()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_spec(self) -> None:
        (self.assets / "animation-spec.json").write_text(
            json.dumps(self.spec, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def write_valid_frames(self) -> None:
        first = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        ImageDraw.Draw(first).rectangle((20, 20, 44, 52), fill=(180, 120, 95, 255))
        first.save(self.frames / "000.png")

        second = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        drawing = ImageDraw.Draw(second)
        drawing.rectangle((20, 20, 44, 52), fill=(180, 120, 95, 255))
        drawing.rectangle((44, 44, 54, 47), fill=(180, 120, 95, 255))
        second.save(self.frames / "001.png")

    def build(self, name: str = "result.catpet") -> tuple[Path, dict]:
        output = self.root / name
        result = build_canonical_package(self.assets, output, require_all=True)
        return output, result

    def test_tail_extent_cannot_move_root_or_world_scale(self) -> None:
        output, _ = self.build()
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        frames = manifest["animations"][0]["frames"]

        self.assertNotEqual(frames[0]["trimRect"], frames[1]["trimRect"])
        self.assertEqual(frames[0]["rootAnchor"], frames[1]["rootAnchor"])
        self.assertEqual(frames[0]["pivot"], frames[1]["pivot"])
        self.assertEqual(frames[0]["sourceSize"], {"width": 64, "height": 64})
        self.assertEqual(frames[1]["sourceSize"], {"width": 64, "height": 64})
        self.assertEqual(manifest["pixelsPerBodyUnit"], 220)
        self.assertNotIn("bodyScale", frames[0])
        self.assertNotIn("bodyScale", frames[1])

    def test_source_pixels_and_alpha_survive_atlas_without_resize(self) -> None:
        output, _ = self.build()
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        frames = manifest["animations"][0]["frames"]
        with Image.open(output / "atlases" / "idle.png") as opened:
            atlas = opened.convert("RGBA")
            for index, frame in enumerate(frames):
                rect = frame["textureRect"]
                crop = atlas.crop(
                    (
                        rect["x"],
                        rect["y"],
                        rect["x"] + rect["width"],
                        rect["y"] + rect["height"],
                    )
                )
                with Image.open(self.frames / f"{index:03d}.png") as source:
                    source_rgba = source.convert("RGBA")
                self.assertEqual(source_rgba.size, crop.size)
                self.assertEqual(source_rgba.tobytes(), crop.tobytes())
                self.assertEqual(
                    frame["sourcePixelSHA256"], canonical_rgba_digest(source_rgba)
                )
                self.assertEqual(frame["sourcePixelSHA256"], frame["atlasPixelSHA256"])

    def test_packaged_component_content_fails_closed_after_digest_rebinding(self) -> None:
        output, _ = self.build()
        manifest_path = output / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        frame = manifest["animations"][0]["frames"][1]
        rect = frame["textureRect"]
        atlas_path = output / frame["image"]
        with Image.open(atlas_path) as opened:
            atlas = opened.convert("RGBA")
        drawing = ImageDraw.Draw(atlas)
        drawing.rectangle(
            (
                rect["x"] + 8,
                rect["y"] + 8,
                rect["x"] + 11,
                rect["y"] + 11,
            ),
            fill=(30, 30, 30, 255),
        )
        atlas.save(atlas_path, optimize=True)
        crop = atlas.crop(
            (
                rect["x"],
                rect["y"],
                rect["x"] + rect["width"],
                rect["y"] + rect["height"],
            )
        )
        digest = canonical_rgba_digest(crop)
        frame["sourcePixelSHA256"] = digest
        frame["atlasPixelSHA256"] = digest
        manifest["animations"][0]["endPoseSignature"]["pixelSHA256"] = digest
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            CanonicalAssetContractError, "disconnected components are forbidden"
        ):
            validate_canonical_package(manifest_path)

    def test_packaging_is_byte_deterministic(self) -> None:
        first, first_result = self.build("first.catpet")
        second, second_result = self.build("second.catpet")
        self.assertEqual(
            first_result["manifestSHA256"], second_result["manifestSHA256"]
        )
        self.assertEqual(tree_digest(first), tree_digest(second))

    def test_invalid_anchor_fails_closed(self) -> None:
        self.spec["actions"][0]["frameMetadata"][1]["rootAnchor"]["x"] = 65
        self.write_spec()
        with self.assertRaisesRegex(
            CanonicalAssetContractError, "outside the authored canvas"
        ):
            self.build()

        self.spec = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.spec["actions"][0]["frameMetadata"][1]["rootAnchor"]["x"] = True
        self.write_spec()
        with self.assertRaisesRegex(CanonicalAssetContractError, "must be numeric"):
            self.build("boolean-anchor.catpet")

    def test_invalid_pose_fails_closed(self) -> None:
        self.spec["actions"][0]["endPose"] = "crouching"
        self.write_spec()
        with self.assertRaisesRegex(CanonicalAssetContractError, "invalid endpoint pose"):
            self.build()

    def test_invalid_color_metadata_fails_closed(self) -> None:
        self.spec["colorSpace"]["name"] = "DisplayP3"
        self.write_spec()
        with self.assertRaisesRegex(CanonicalAssetContractError, "sRGB RGBA8"):
            self.build()

    def test_mismatched_canvas_and_unsafe_margin_fail_closed(self) -> None:
        wrong_size = Image.new("RGBA", (65, 64), (0, 0, 0, 0))
        ImageDraw.Draw(wrong_size).rectangle(
            (20, 20, 44, 52), fill=(180, 120, 95, 255)
        )
        wrong_size.save(self.frames / "001.png")
        with self.assertRaisesRegex(CanonicalAssetContractError, "fixed authored canvas"):
            self.build()

        self.write_valid_frames()
        unsafe = Image.open(self.frames / "001.png").convert("RGBA")
        ImageDraw.Draw(unsafe).rectangle((1, 30, 4, 33), fill=(180, 120, 95, 255))
        unsafe.save(self.frames / "001.png")
        with self.assertRaisesRegex(CanonicalAssetContractError, "safe margin"):
            self.build("unsafe.catpet")

    def test_disconnected_components_require_one_bounded_review(self) -> None:
        image = Image.open(self.frames / "001.png").convert("RGBA")
        ImageDraw.Draw(image).rectangle((8, 8, 11, 11), fill=(30, 30, 30, 255))
        image.save(self.frames / "001.png")
        with self.assertRaisesRegex(
            CanonicalAssetContractError, "disconnected components are forbidden"
        ):
            self.build()

        self.spec["componentPolicy"]["exceptions"] = [
            {
                "reviewId": "B3-SYNTHETIC-001",
                "issue": "#16",
                "owner": "repository maintainers",
                "reviewedBy": "B3 fixture review",
                "reason": "Proves a bounded semantic component exception.",
                "animation": "idle",
                "frames": [1],
                "maximumSecondaryComponents": 1,
                "maximumSecondaryArea": 16,
            }
        ]
        self.write_spec()
        output, _ = self.build("reviewed-component.catpet")
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(
            manifest["animations"][0]["frames"][1]["componentExceptionReviewId"],
            "B3-SYNTHETIC-001",
        )

    def test_canonical_authoring_forbids_action_resize(self) -> None:
        self.spec["actions"][0]["authoringScale"] = 1.25
        self.write_spec()
        with self.assertRaisesRegex(CanonicalAssetContractError, "authoringScale"):
            self.build()

    def test_pose_signatures_bind_actual_endpoints(self) -> None:
        output, _ = self.build()
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        animation = manifest["animations"][0]
        self.assertEqual(animation["startPoseSignature"]["pose"], "seated")
        self.assertEqual(animation["startPoseSignature"]["frameIndex"], 0)
        self.assertEqual(
            animation["startPoseSignature"]["pixelSHA256"],
            animation["frames"][0]["atlasPixelSHA256"],
        )
        self.assertEqual(animation["endPoseSignature"]["pose"], "seated")
        self.assertEqual(animation["endPoseSignature"]["frameIndex"], 1)
        self.assertEqual(
            animation["endPoseSignature"]["pixelSHA256"],
            animation["frames"][1]["atlasPixelSHA256"],
        )

    def test_legacy_authoring_requires_explicit_compatibility_mode(self) -> None:
        legacy_assets = self.root / "LegacyAssets"
        legacy_frames = legacy_assets / "frames" / "idle"
        legacy_frames.mkdir(parents=True)
        shutil.copy2(self.frames / "000.png", legacy_frames / "000.png")
        legacy_spec = {
            "petId": "legacy-cat",
            "displayName": "Legacy Cat",
            "assetVersion": "legacy-fixture",
            "pixelsPerBodyUnit": 220,
            "minimumFramesPerAnimation": 1,
            "actions": [
                {
                    "id": "idle",
                    "loop": True,
                    "fps": 12,
                    "authoringScale": 1.5,
                    "startPose": "seated",
                    "endPose": "seated",
                }
            ],
        }
        (legacy_assets / "animation-spec.json").write_text(
            json.dumps(legacy_spec), encoding="utf-8"
        )
        script = REPOSITORY_ROOT / "Scripts" / "build_catpet.py"
        output = self.root / "legacy.catpet"
        implicit = subprocess.run(
            [
                sys.executable,
                str(script),
                "--assets-root",
                str(legacy_assets),
                "--output",
                str(output),
                "--require-all",
            ],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(implicit.returncode, 0)
        self.assertIn("explicit --legacy-v1", implicit.stderr)
        self.assertFalse(output.exists())

        explicit = subprocess.run(
            [
                sys.executable,
                str(script),
                "--assets-root",
                str(legacy_assets),
                "--output",
                str(output),
                "--require-all",
                "--legacy-v1",
            ],
            cwd=REPOSITORY_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(explicit.returncode, 0, explicit.stderr)
        manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["formatVersion"], 1)
        self.assertEqual(
            manifest["animations"][0]["frames"][0]["sourceSize"],
            {"width": 96, "height": 96},
        )
        self.assertEqual(manifest["animations"][0]["frames"][0]["bodyScale"], 1.0)

    def test_default_production_package_is_never_rewritten(self) -> None:
        before = tree_digest(DEFAULT_PACKAGE)
        self.build()
        with self.assertRaisesRegex(
            CanonicalAssetContractError, "refusing a silent rewrite"
        ):
            build_canonical_package(self.assets, DEFAULT_PACKAGE, require_all=True)
        after = tree_digest(DEFAULT_PACKAGE)
        self.assertEqual(before, after)

    def test_incomplete_identity_rig_fails_closed(self) -> None:
        del self.spec["identityRig"]["views"][0]["landmarks"]["tailRoot"]
        self.write_spec()
        with self.assertRaisesRegex(
            CanonicalAssetContractError, "missing identity landmarks: tailRoot"
        ):
            self.build()

    def test_missing_component_review_fields_fail_closed(self) -> None:
        invalid = copy.deepcopy(self.spec["componentPolicy"])
        invalid["exceptions"] = [{"reviewId": "incomplete"}]
        self.spec["componentPolicy"] = invalid
        self.write_spec()
        with self.assertRaisesRegex(
            CanonicalAssetContractError, "incomplete review metadata"
        ):
            self.build()


if __name__ == "__main__":
    unittest.main()
