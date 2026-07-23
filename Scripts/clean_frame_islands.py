#!/usr/bin/env python3
"""Report and optionally remove remote alpha islands left by strip extraction."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image


def components(alpha: Image.Image, threshold: int) -> list[dict]:
    width, height = alpha.size
    occupied = [value >= threshold for value in alpha.getdata()]
    seen = bytearray(width * height)
    result = []
    for start, value in enumerate(occupied):
        if not value or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        pixels = []
        min_x = max_x = start % width
        min_y = max_y = start // width
        while stack:
            current = stack.pop()
            pixels.append(current)
            x, y = current % width, current // width
            min_x, max_x = min(min_x, x), max(max_x, x)
            min_y, max_y = min(min_y, y), max(max_y, y)
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = ny * width + nx
                    if occupied[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
        result.append({"pixels": pixels, "size": len(pixels), "bbox": [min_x, min_y, max_x + 1, max_y + 1]})
    return sorted(result, key=lambda item: item["size"], reverse=True)


def bbox_gap(first: list[int], second: list[int]) -> float:
    dx = max(first[0] - second[2], second[0] - first[2], 0)
    dy = max(first[1] - second[3], second[1] - first[3], 0)
    return math.hypot(dx, dy)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames-root", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--alpha-threshold", type=int, default=12)
    parser.add_argument("--max-relative-size", type=float, default=0.06)
    parser.add_argument("--min-gap", type=float, default=8)
    parser.add_argument("--tiny-pixels", type=int, default=24)
    parser.add_argument("--force-action", action="append", default=[],
                        help="remove every disconnected secondary component for a reviewed action")
    args = parser.parse_args()

    frame_reports = []
    modified = 0
    removed_components = 0
    removed_pixels = 0
    for path in sorted(args.frames_root.glob("**/*.png")):
        image = Image.open(path).convert("RGBA")
        groups = components(image.getchannel("A"), args.alpha_threshold)
        if len(groups) <= 1:
            continue
        largest = groups[0]
        force_action = path.parent.name in set(args.force_action)
        candidates = []
        removal = set()
        for group in groups[1:]:
            ratio = group["size"] / largest["size"]
            gap = bbox_gap(largest["bbox"], group["bbox"])
            should_remove = force_action or group["size"] <= args.tiny_pixels or (
                ratio <= args.max_relative_size and gap >= args.min_gap
            )
            candidates.append({
                "size": group["size"], "ratioToLargest": round(ratio, 5),
                "gap": round(gap, 2), "bbox": group["bbox"], "remove": should_remove,
            })
            if should_remove:
                removal.update(group["pixels"])
        if candidates:
            frame_reports.append({"frame": str(path), "largestSize": largest["size"], "components": candidates})
        if args.apply and removal:
            pixels = list(image.getdata())
            for index in removal:
                r, g, b, _ = pixels[index]
                pixels[index] = (r, g, b, 0)
            cleaned = Image.new("RGBA", image.size)
            cleaned.putdata(pixels)
            cleaned.save(path, optimize=True)
            modified += 1
            removed_components += sum(1 for item in candidates if item["remove"])
            removed_pixels += len(removal)

    report = {
        "ok": True,
        "applied": args.apply,
        "modifiedFrames": modified,
        "removedComponents": removed_components,
        "removedPixels": removed_pixels,
        "framesWithMultipleComponents": len(frame_reports),
        "frames": frame_reports,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key != "frames"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
