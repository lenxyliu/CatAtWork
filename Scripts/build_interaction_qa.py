#!/usr/bin/env python3
"""Build deterministic B4 interaction sheets and repeated native-scale previews."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from build_foundation_qa import (
    BACKGROUND,
    GRID,
    LOOP_REPETITIONS,
    TEXT,
    contact_sheet,
    fixed_background,
    sha256_file,
)


SCHEMA = "catatwork.interaction-qa/v1"
NON_LOOP_REPETITIONS = 3
DIRECTION_ACTIONS = ("petting", "earPet", "chinPet", "backPet")


def load_actions(
    candidate_root: Path,
) -> tuple[dict[str, Any], dict[str, list[Image.Image]]]:
    spec = json.loads(
        (candidate_root / "animation-spec.json").read_text(
            encoding="utf-8"
        )
    )
    semantics = {
        action["id"]: action
        for action in spec["actions"]
        if action["id"] != "idle"
    }
    actions: dict[str, list[Image.Image]] = {}
    for identifier in semantics:
        paths = sorted(
            (candidate_root / "frames" / identifier).glob("*.png")
        )
        if len(paths) != 24:
            raise ValueError(f"{identifier}: expected exactly 24 frames")
        actions[identifier] = [
            Image.open(path).convert("RGBA") for path in paths
        ]
    return semantics, actions


def direction_pair(frame: Image.Image) -> Image.Image:
    right = fixed_background(frame)
    left = fixed_background(
        frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    )
    gap = 17
    result = Image.new(
        "RGBA",
        (right.width * 2 + gap, right.height + 28),
        BACKGROUND,
    )
    result.alpha_composite(right, (0, 28))
    result.alpha_composite(left, (right.width + gap, 28))
    draw = ImageDraw.Draw(result)
    draw.text((8, 7), "base: screen-right", fill=TEXT)
    draw.text((right.width + gap + 8, 7), "runtime mirror: screen-left", fill=TEXT)
    draw.line(
        (right.width + gap // 2, 0, right.width + gap // 2, result.height),
        fill=GRID,
        width=1,
    )
    return result


def build(candidate_root: Path, output_root: Path) -> dict[str, Any]:
    if output_root.exists():
        raise ValueError(f"output already exists: {output_root}")
    output_root.mkdir(parents=True)
    semantics, actions = load_actions(candidate_root)
    outputs: list[dict[str, Any]] = []
    reviews: list[dict[str, Any]] = []
    for identifier, frames in actions.items():
        for alignment in ("root", "head"):
            path = output_root / f"{identifier}-{alignment}.png"
            contact_sheet(
                frames,
                title=identifier,
                align=alignment,
            ).save(path, format="PNG", optimize=True)
            outputs.append(
                {
                    "path": str(path),
                    "sha256": sha256_file(path),
                    "kind": f"{alignment}-aligned-contact",
                    "action": identifier,
                }
            )
        looped = bool(semantics[identifier]["loop"])
        repetitions = (
            LOOP_REPETITIONS if looped else NON_LOOP_REPETITIONS
        )
        review_frames = [
            fixed_background(frame)
            for frame in frames
        ] * repetitions
        gif_path = output_root / f"{identifier}-fixed-background.gif"
        duration = round(1000 / float(semantics[identifier]["fps"]))
        review_frames[0].save(
            gif_path,
            save_all=True,
            append_images=review_frames[1:],
            duration=duration,
            loop=0,
            disposal=2,
        )
        outputs.append(
            {
                "path": str(gif_path),
                "sha256": sha256_file(gif_path),
                "kind": "fixed-background-review",
                "action": identifier,
            }
        )
        if identifier in DIRECTION_ACTIONS:
            pair_frames = [
                direction_pair(frame)
                for frame in frames
            ] * repetitions
            pair_path = output_root / f"{identifier}-direction-pair.gif"
            pair_frames[0].save(
                pair_path,
                save_all=True,
                append_images=pair_frames[1:],
                duration=duration,
                loop=0,
                disposal=2,
            )
            outputs.append(
                {
                    "path": str(pair_path),
                    "sha256": sha256_file(pair_path),
                    "kind": "runtime-direction-pair-review",
                    "action": identifier,
                }
            )
        reviews.append(
            {
                "action": identifier,
                "looped": looped,
                "repetitions": repetitions,
                "encodedFrameCount": len(review_frames),
                "fps": semantics[identifier]["fps"],
                "backgroundRGBA": list(BACKGROUND),
                "supportLineY": 537,
                "nativeFrameSize": [665, 737],
            }
        )
    report = {
        "schemaVersion": SCHEMA,
        "candidate": {
            "path": str(candidate_root),
            "animationSpecSHA256": sha256_file(
                candidate_root / "animation-spec.json"
            ),
        },
        "summary": {
            "actionCount": len(actions),
            "outputCount": len(outputs),
            "loopedActionCount": sum(
                item["looped"] for item in reviews
            ),
            "loopRepetitions": LOOP_REPETITIONS,
            "nonLoopRepetitions": NON_LOOP_REPETITIONS,
        },
        "reviews": reviews,
        "outputs": outputs,
    }
    report_path = output_root / "qa-report.json"
    report_path.write_text(
        json.dumps(
            report,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return {
        "output": str(output_root),
        "report": str(report_path),
        **report["summary"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-root", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()
    print(
        json.dumps(
            build(args.candidate_root, args.output_root),
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
