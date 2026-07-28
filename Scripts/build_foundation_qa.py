#!/usr/bin/env python3
"""Build deterministic B4 foundation root/head sheets and five-loop previews."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


SCHEMA = "catatwork.foundation-qa/v1"
BACKGROUND = (216, 220, 226, 255)
GRID = (174, 180, 190, 255)
TEXT = (25, 27, 31, 255)
SUPPORT = (120, 126, 136, 255)
ALPHA_THRESHOLD = 12
LOOP_REPETITIONS = 5


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def head_proxy(image: Image.Image) -> tuple[float, float]:
    alpha = image.getchannel("A")
    bbox = alpha.point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    ).getbbox()
    if bbox is None:
        raise ValueError("cannot head-align an empty frame")
    top_end = bbox[1] + max(1, round((bbox[3] - bbox[1]) * 0.42))
    occupied = [
        (x, y)
        for y in range(bbox[1], top_end)
        for x in range(bbox[0], bbox[2])
        if alpha.getpixel((x, y)) >= ALPHA_THRESHOLD
    ]
    if not occupied:
        raise ValueError("cannot find the head proxy")
    return (
        sum(point[0] for point in occupied) / len(occupied),
        sum(point[1] for point in occupied) / len(occupied),
    )


def fixed_background(image: Image.Image) -> Image.Image:
    result = Image.new("RGBA", image.size, BACKGROUND)
    result.alpha_composite(image)
    draw = ImageDraw.Draw(result)
    draw.line((0, 537, result.width, 537), fill=SUPPORT, width=1)
    return result


def head_aligned(image: Image.Image) -> Image.Image:
    proxy_x, proxy_y = head_proxy(image)
    result = Image.new("RGBA", image.size, BACKGROUND)
    shift = (round(332.5 - proxy_x), round(215 - proxy_y))
    result.alpha_composite(image, shift)
    draw = ImageDraw.Draw(result)
    draw.line((332, 0, 332, result.height), fill=GRID, width=1)
    draw.line((0, 215, result.width, 215), fill=GRID, width=1)
    return result


def contact_sheet(
    frames: list[Image.Image],
    *,
    title: str,
    align: str,
) -> Image.Image:
    cell_width, cell_height, label_height = 224, 248, 20
    columns = 8
    rows = (len(frames) + columns - 1) // columns
    sheet = Image.new(
        "RGBA",
        (cell_width * columns, 28 + (cell_height + label_height) * rows),
        BACKGROUND,
    )
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 7), f"{title} · {align}-aligned", fill=TEXT)
    for index, frame in enumerate(frames):
        aligned = fixed_background(frame) if align == "root" else head_aligned(frame)
        aligned.thumbnail((cell_width, cell_height), Image.Resampling.NEAREST)
        column, row = index % columns, index // columns
        x = column * cell_width + (cell_width - aligned.width) // 2
        y = 28 + row * (cell_height + label_height)
        sheet.alpha_composite(aligned, (x, y))
        draw.rectangle(
            (
                column * cell_width,
                y,
                (column + 1) * cell_width - 1,
                y + cell_height - 1,
            ),
            outline=GRID,
        )
        draw.text(
            (column * cell_width + 5, y + cell_height + 2),
            f"{index + 1:02d}",
            fill=TEXT,
        )
    return sheet


def load_actions(candidate_root: Path) -> tuple[dict[str, Any], dict[str, list[Image.Image]]]:
    spec = json.loads(
        (candidate_root / "animation-spec.json").read_text(encoding="utf-8")
    )
    actions: dict[str, list[Image.Image]] = {}
    for action in spec["actions"]:
        identifier = action["id"]
        paths = sorted((candidate_root / "frames" / identifier).glob("*.png"))
        if len(paths) != 24:
            raise ValueError(f"{identifier}: expected exactly 24 frames")
        actions[identifier] = [Image.open(path).convert("RGBA") for path in paths]
    return spec, actions


def build(candidate_root: Path, output_root: Path) -> dict[str, Any]:
    if output_root.exists():
        raise ValueError(f"output already exists: {output_root}")
    output_root.mkdir(parents=True)
    spec, actions = load_actions(candidate_root)
    semantics = {action["id"]: action for action in spec["actions"]}
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
        review_frames = [fixed_background(frame) for frame in frames]
        repetitions = (
            LOOP_REPETITIONS if semantics[identifier]["loop"] else 1
        )
        review_frames = review_frames * repetitions
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
        reviews.append(
            {
                "action": identifier,
                "looped": bool(semantics[identifier]["loop"]),
                "repetitions": repetitions,
                "encodedFrameCount": len(review_frames),
                "fps": semantics[identifier]["fps"],
                "backgroundRGBA": list(BACKGROUND),
                "supportLineY": 537,
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
            "loopedActionCount": sum(item["looped"] for item in reviews),
            "loopRepetitions": LOOP_REPETITIONS,
        },
        "reviews": reviews,
        "outputs": outputs,
    }
    report_path = output_root / "qa-report.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
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
