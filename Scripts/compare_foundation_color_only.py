#!/usr/bin/env python3
"""Prove that a foundation rebuild changes RGB and no non-color pixels."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image

from validate_foundation_assets import EXPECTED_ACTIONS
from validate_visual_qa import canonical_bytes, sha256_file


REPORT_SCHEMA = "catatwork.foundation-color-only-diff/v1"


def alpha_sha256(image: Image.Image) -> str:
    return hashlib.sha256(image.getchannel("A").tobytes()).hexdigest()


def compare_images(
    before: Image.Image,
    after: Image.Image,
    *,
    visible_alpha_minimum: int,
) -> dict[str, Any]:
    before_rgba = before.convert("RGBA")
    after_rgba = after.convert("RGBA")
    alpha_changes = 0
    rgb_changes = 0
    visible_rgb_changes = 0
    hidden_rgb_changes = 0
    for old, new in zip(before_rgba.getdata(), after_rgba.getdata()):
        if old[3] != new[3]:
            alpha_changes += 1
        if old[:3] != new[:3]:
            rgb_changes += 1
            if old[3] >= visible_alpha_minimum:
                visible_rgb_changes += 1
            else:
                hidden_rgb_changes += 1
    return {
        "sizeIdentity": before_rgba.size == after_rgba.size,
        "alphaChanges": alpha_changes,
        "rgbChanges": rgb_changes,
        "visibleRGBChanges": visible_rgb_changes,
        "hiddenRGBChanges": hidden_rgb_changes,
        "beforeAlphaSHA256": alpha_sha256(before_rgba),
        "afterAlphaSHA256": alpha_sha256(after_rgba),
    }


def frame_paths(root: Path, action: str) -> list[Path]:
    paths = sorted((root / action).glob("*.png"))
    expected = [f"{index:03d}.png" for index in range(24)]
    if [path.name for path in paths] != expected:
        raise ValueError(f"{action}: expected frames 000.png through 023.png")
    return paths


def compare_foundation_color_only(
    *,
    before_root: Path,
    after_root: Path,
    visible_alpha_minimum: int,
) -> dict[str, Any]:
    frames = []
    violations = []
    for action in EXPECTED_ACTIONS:
        before_paths = frame_paths(before_root, action)
        after_paths = frame_paths(after_root, action)
        for index, (before_path, after_path) in enumerate(
            zip(before_paths, after_paths)
        ):
            with Image.open(before_path) as before_opened, Image.open(
                after_path
            ) as after_opened:
                before_mode = before_opened.mode
                after_mode = after_opened.mode
                before_icc = bool(before_opened.info.get("icc_profile"))
                after_icc = bool(after_opened.info.get("icc_profile"))
                measurement = compare_images(
                    before_opened,
                    after_opened,
                    visible_alpha_minimum=visible_alpha_minimum,
                )
            passed = (
                before_mode == "RGBA"
                and after_mode == "RGBA"
                and not before_icc
                and not after_icc
                and measurement["sizeIdentity"]
                and measurement["alphaChanges"] == 0
                and measurement["beforeAlphaSHA256"]
                == measurement["afterAlphaSHA256"]
                and measurement["hiddenRGBChanges"] == 0
                and measurement["visibleRGBChanges"] > 0
            )
            record = {
                "action": action,
                "frame": index,
                "beforeSHA256": sha256_file(before_path),
                "afterSHA256": sha256_file(after_path),
                "beforeMode": before_mode,
                "afterMode": after_mode,
                "beforeEmbeddedICC": before_icc,
                "afterEmbeddedICC": after_icc,
                **measurement,
                "passed": passed,
            }
            frames.append(record)
            if not passed:
                violations.append(
                    {
                        "action": action,
                        "frame": index,
                        "measurement": record,
                    }
                )
    changed_frames = sum(frame["visibleRGBChanges"] > 0 for frame in frames)
    return {
        "schemaVersion": REPORT_SCHEMA,
        "scope": {
            "actions": list(EXPECTED_ACTIONS),
            "frameCount": len(frames),
            "visibleAlphaMinimum": visible_alpha_minimum,
        },
        "frames": frames,
        "summary": {
            "decision": (
                "pass"
                if not violations
                and len(frames) == 216
                and changed_frames == 216
                else "fail"
            ),
            "changedFrameCount": changed_frames,
            "alphaChangeCount": sum(frame["alphaChanges"] for frame in frames),
            "hiddenRGBChangeCount": sum(
                frame["hiddenRGBChanges"] for frame in frames
            ),
            "visibleRGBChangeCount": sum(
                frame["visibleRGBChanges"] for frame in frames
            ),
            "violationCount": len(violations),
            "violations": violations,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--before-root", required=True, type=Path)
    parser.add_argument("--after-root", required=True, type=Path)
    parser.add_argument("--visible-alpha-minimum", type=int, default=12)
    parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = compare_foundation_color_only(
        before_root=args.before_root,
        after_root=args.after_root,
        visible_alpha_minimum=args.visible_alpha_minimum,
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_bytes(canonical_bytes(report, pretty=True))
    print(
        json.dumps(
            {
                "decision": report["summary"]["decision"],
                "report": str(args.report),
                "changedFrameCount": report["summary"]["changedFrameCount"],
                "visibleRGBChangeCount": report["summary"][
                    "visibleRGBChangeCount"
                ],
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    if report["summary"]["decision"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
