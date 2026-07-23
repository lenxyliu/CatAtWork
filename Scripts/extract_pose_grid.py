#!/usr/bin/env python3
"""Extract an imagegen pose grid without resizing or clipping silhouettes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

from extract_pose_strip import remove_green_key, remove_tiny_islands


def connected_components(alpha: Image.Image, threshold: int) -> list[dict[str, float | int]]:
    """Return complete silhouette components with area, bbox and centroid."""
    width, height = alpha.size
    occupied = bytearray(1 if value >= threshold else 0 for value in alpha.getdata())
    seen = bytearray(width * height)
    result: list[dict[str, float | int]] = []
    for start, value in enumerate(occupied):
        if not value or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        area = sum_x = sum_y = 0
        min_x, min_y, max_x, max_y = width, height, 0, 0
        while stack:
            current = stack.pop()
            x, y = current % width, current // width
            area += 1
            sum_x += x
            sum_y += y
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x + 1), max(max_y, y + 1)
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if occupied[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
        if area >= 16:
            result.append({
                "area": area,
                "minX": min_x, "minY": min_y, "maxX": max_x, "maxY": max_y,
                "centerX": sum_x / area, "centerY": sum_y / area,
            })
    return result


def pose_groups(alpha: Image.Image, rows: int, columns: int, threshold: int) -> list[list[dict]]:
    """Find the eight main cats, then attach detached paws/tails to the nearest cat."""
    expected = rows * columns
    components = connected_components(alpha, threshold)
    if len(components) < expected:
        return []
    anchors = sorted(components, key=lambda item: item["area"], reverse=True)[:expected]
    # Imagegen follows the requested row-major layout, but tall airborne poses
    # can cross the theoretical horizontal midpoint. Sort actual body anchors,
    # not fixed grid cells, to retain those complete silhouettes.
    anchors_by_row = sorted(anchors, key=lambda item: item["centerY"])
    ordered: list[dict] = []
    for row in range(rows):
        row_anchors = anchors_by_row[row * columns:(row + 1) * columns]
        ordered.extend(sorted(row_anchors, key=lambda item: item["centerX"]))
    groups: list[list[dict]] = [[anchor] for anchor in ordered]
    anchor_ids = {id(anchor) for anchor in anchors}
    for component in components:
        if id(component) in anchor_ids:
            continue
        nearest = min(range(expected), key=lambda index: (
            ((component["centerX"] - ordered[index]["centerX"]) / alpha.width) ** 2 +
            ((component["centerY"] - ordered[index]["centerY"]) / alpha.height) ** 2
        ))
        groups[nearest].append(component)
    return groups


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--rows", type=int, default=2)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--start-index", type=int, default=0)
    parser.add_argument("--padding", type=int, default=24)
    parser.add_argument("--alpha-threshold", type=int, default=12)
    parser.add_argument("--minimum-clearance", type=int, default=5)
    parser.add_argument("--json-out", required=True, type=Path)
    args = parser.parse_args()

    if args.rows < 1 or args.columns < 1:
        raise SystemExit("rows and columns must be positive")

    image = remove_green_key(Image.open(args.input).convert("RGBA"))
    # Keying can leave isolated near-transparent pixels far from the cat. Clean
    # those before measuring cell clearance so a chroma speck cannot masquerade
    # as anatomy touching a grid boundary.
    image = remove_tiny_islands(image, args.alpha_threshold)
    alpha = image.getchannel("A").point(lambda value: 0 if value < args.alpha_threshold else value)
    image.putalpha(alpha)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    frames = []
    groups = pose_groups(alpha, args.rows, args.columns, args.alpha_threshold)
    if len(groups) != args.rows * args.columns:
        raise SystemExit(f"expected {args.rows * args.columns} complete pose bodies")

    for index, group in enumerate(groups):
            row, column = divmod(index, args.columns)
            source_bbox = (
                min(int(component["minX"]) for component in group),
                min(int(component["minY"]) for component in group),
                max(int(component["maxX"]) for component in group),
                max(int(component["maxY"]) for component in group),
            )
            clearance = min(
                source_bbox[0], source_bbox[1],
                image.width - source_bbox[2], image.height - source_bbox[3],
            )
            if clearance < args.minimum_clearance:
                raise SystemExit(
                    f"pose {index} touches the source edge (clearance={clearance}); refusing to crop anatomy"
                )
            content = remove_tiny_islands(image.crop(source_bbox), args.alpha_threshold)
            frame = Image.new(
                "RGBA",
                (content.width + args.padding * 2, content.height + args.padding * 2),
                (0, 0, 0, 0),
            )
            frame.alpha_composite(content, (args.padding, args.padding))
            output = args.output_dir / f"{args.start_index + index:03d}.png"
            frame.save(output, optimize=True)
            content_bbox = frame.getchannel("A").getbbox()
            if content_bbox is None:
                raise SystemExit(f"pose {index} became empty after cleanup")
            frames.append({
                "index": args.start_index + index,
                "image": str(output),
                "sourceGridRect": {
                    "x": source_bbox[0], "y": source_bbox[1],
                    "width": content.width, "height": content.height,
                },
                "contentRect": {
                    "x": content_bbox[0], "y": content_bbox[1],
                    "width": content_bbox[2] - content_bbox[0],
                    "height": content_bbox[3] - content_bbox[1],
                },
                "gridCell": {"row": row, "column": column},
                "assignedComponents": len(group),
                "boundaryClearance": clearance,
                "pixelScaleChanged": False,
            })

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps({
        "ok": True,
        "layout": {"rows": args.rows, "columns": args.columns},
        "sourceSize": list(image.size),
        "frames": frames,
    }, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
