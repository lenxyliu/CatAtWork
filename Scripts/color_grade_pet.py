#!/usr/bin/env python3
"""Apply one fixed, conservative palette grade without changing alpha or geometry."""

from __future__ import annotations

import argparse
from pathlib import Path
from PIL import Image


def histogram(path: Path) -> list[list[int]]:
    image = Image.open(path).convert("RGBA")
    result = [[0] * 256 for _ in range(3)]
    for r, g, b, a in image.getdata():
        if a < 40 or (b > r * 1.14 and b > g * 1.04 and b > 100):
            continue
        for channel, value in enumerate((r, g, b)):
            result[channel][value] += 1
    return result


def quantile_lut(source: list[int], target: list[int], strength: float) -> list[int]:
    source_total, target_total = sum(source), sum(target)
    source_cdf, target_cdf = [], []
    running = 0
    for count in source:
        running += count
        source_cdf.append(running / max(source_total, 1))
    running = 0
    for count in target:
        running += count
        target_cdf.append(running / max(target_total, 1))
    lut, target_index = [], 0
    for value, quantile in enumerate(source_cdf):
        while target_index < 255 and target_cdf[target_index] < quantile:
            target_index += 1
        # Clamp the correction as well as blending it: this is tonal calibration,
        # never a repaint or an identity-changing palette replacement.
        mapped = max(value - 18, min(value + 18, target_index))
        lut.append(round(value + (mapped - value) * strength))
    return lut


def grade(path: Path, luts: list[list[int]]) -> None:
    image = Image.open(path).convert("RGBA")
    pixels = []
    for r, g, b, a in image.getdata():
        if a == 0:
            pixels.append((r, g, b, a))
            continue
        if b > r * 1.14 and b > g * 1.04 and b > 100:
            # Midpoint between the generated vivid cyan-blue iris and the local
            # Codex cat's pale grey-blue iris, while retaining pixel luminance.
            luminance = (r + g + b) / 3
            target = (131, 166, 191)
            target_luminance = sum(target) / 3
            scale = luminance / target_luminance
            r, g, b = (round(r * 0.35 + target[0] * scale * 0.65),
                       round(g * 0.35 + target[1] * scale * 0.65),
                       round(b * 0.35 + target[2] * scale * 0.65))
        else:
            r, g, b = luts[0][r], luts[1][g], luts[2][b]
        pixels.append((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), a))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    result.save(path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames-root", required=True, type=Path)
    parser.add_argument("--source-reference", required=True, type=Path)
    parser.add_argument("--target-reference", required=True, type=Path)
    parser.add_argument("--strength", type=float, default=0.20)
    args = parser.parse_args()
    source = histogram(args.source_reference)
    target = histogram(args.target_reference)
    luts = [quantile_lut(source[i], target[i], args.strength) for i in range(3)]
    paths = sorted(args.frames_root.glob("**/*.png"))
    for path in paths:
        grade(path, luts)
    print(f"graded {len(paths)} frames; alpha and dimensions preserved")


if __name__ == "__main__":
    main()
