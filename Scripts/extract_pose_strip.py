#!/usr/bin/env python3
"""Extract separated imagegen pose groups without resizing any pet pixels."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def component_slot_runs(alpha: Image.Image, expected: int, threshold: int) -> list[tuple[int, int]]:
    """Assign complete connected silhouettes to their nearest expected pose slot.

    Image-generated pose strips are laid out left-to-right, but a rotated cat can
    contain a detached paw or tail and can extend beyond its nominal eighth of
    the strip. Cutting at fixed slot boundaries therefore amputates anatomy.
    This scan-line connected-component pass keeps every silhouette component
    intact, then groups components around the eight expected pose centres.
    """
    width, height = alpha.size
    pixels = alpha.tobytes()
    parent: list[int] = []
    stats: list[list[int]] = []  # area, min_x, min_y, max_x_exclusive, max_y_exclusive, sum_x
    previous: list[tuple[int, int, int]] = []

    def new_label(x0: int, x1: int, y: int) -> int:
        label = len(parent)
        parent.append(label)
        count = x1 - x0
        stats.append([count, x0, y, x1, y + 1, (x0 + x1 - 1) * count // 2])
        return label

    def find(label: int) -> int:
        while parent[label] != label:
            parent[label] = parent[parent[label]]
            label = parent[label]
        return label

    def union(lhs: int, rhs: int) -> int:
        lhs, rhs = find(lhs), find(rhs)
        if lhs == rhs:
            return lhs
        if lhs > rhs:
            lhs, rhs = rhs, lhs
        parent[rhs] = lhs
        return lhs

    for y in range(height):
        row_start = y * width
        current: list[tuple[int, int, int]] = []
        x = 0
        previous_index = 0
        while x < width:
            while x < width and pixels[row_start + x] < threshold:
                x += 1
            if x >= width:
                break
            x0 = x
            while x < width and pixels[row_start + x] >= threshold:
                x += 1
            x1 = x
            while previous_index < len(previous) and previous[previous_index][1] <= x0:
                previous_index += 1
            overlap_labels: list[int] = []
            probe = previous_index
            while probe < len(previous) and previous[probe][0] < x1:
                overlap_labels.append(previous[probe][2])
                probe += 1
            if overlap_labels:
                label = find(overlap_labels[0])
                for other in overlap_labels[1:]:
                    label = union(label, other)
                count = x1 - x0
                stats[label][0] += count
                stats[label][1] = min(stats[label][1], x0)
                stats[label][2] = min(stats[label][2], y)
                stats[label][3] = max(stats[label][3], x1)
                stats[label][4] = max(stats[label][4], y + 1)
                stats[label][5] += (x0 + x1 - 1) * count // 2
            else:
                label = new_label(x0, x1, y)
            current.append((x0, x1, label))
        previous = current

    combined: dict[int, list[int]] = {}
    for label, values in enumerate(stats):
        root = find(label)
        if root not in combined:
            combined[root] = values.copy()
        elif root != label:
            target = combined[root]
            target[0] += values[0]
            target[1] = min(target[1], values[1])
            target[2] = min(target[2], values[2])
            target[3] = max(target[3], values[3])
            target[4] = max(target[4], values[4])
            target[5] += values[5]

    slot_width = width / expected
    slots: list[list[list[int]]] = [[] for _ in range(expected)]
    for values in combined.values():
        area, min_x, _, max_x, _, sum_x = values
        if area < 16:
            continue
        centroid_x = sum_x / area
        slot = min(expected - 1, max(0, int(centroid_x / slot_width)))
        expected_center = (slot + 0.5) * slot_width
        if abs(centroid_x - expected_center) <= slot_width * 0.72:
            slots[slot].append(values)

    result: list[tuple[int, int]] = []
    for index, components in enumerate(slots):
        if not components:
            return []
        largest_area = max(component[0] for component in components)
        minimum_area = max(16, round(largest_area * 0.0002))
        kept = [component for component in components if component[0] >= minimum_area]
        if not kept:
            return []
        left = min(component[1] for component in kept)
        right = max(component[3] for component in kept)
        # A union that crosses most of a neighbouring slot indicates that two
        # poses actually touched; fail instead of silently producing a bad frame.
        expected_center = (index + 0.5) * slot_width
        if left < expected_center - slot_width * 0.82 or right > expected_center + slot_width * 0.82:
            return []
        result.append((left, right))
    return result


def remove_green_key(image: Image.Image) -> Image.Image:
    """Remove an imagegen chroma-green field while preserving fur edge coverage."""
    samples = [
        image.getpixel((0, 0)),
        image.getpixel((image.width - 1, 0)),
        image.getpixel((0, image.height - 1)),
        image.getpixel((image.width - 1, image.height - 1)),
    ]
    if not all(g - max(r, b) >= 45 for r, g, b, _ in samples):
        return image

    cleaned = []
    for r, g, b, original_alpha in image.getdata():
        dominance = g - max(r, b)
        if dominance >= 55:
            key_alpha = 0
        elif dominance <= 15:
            key_alpha = 255
        else:
            key_alpha = round((55 - dominance) * 255 / 40)
        alpha = original_alpha * key_alpha // 255
        # Suppress green spill only on partially keyed edge pixels.
        if key_alpha < 255:
            g = min(g, max(r, b) + 8)
        cleaned.append((r, g, b, alpha))
    result = Image.new("RGBA", image.size)
    result.putdata(cleaned)
    return result


def occupied_runs(alpha: Image.Image, threshold: int, min_gap: int) -> list[tuple[int, int]]:
    occupied = []
    for x in range(alpha.width):
        bbox = alpha.crop((x, 0, x + 1, alpha.height)).point(lambda value: 255 if value >= threshold else 0).getbbox()
        occupied.append(bbox is not None)

    raw: list[tuple[int, int]] = []
    start = None
    for x, value in enumerate(occupied + [False]):
        if value and start is None:
            start = x
        elif not value and start is not None:
            raw.append((start, x))
            start = None

    merged: list[tuple[int, int]] = []
    for run in raw:
        if merged and run[0] - merged[-1][1] < min_gap:
            merged[-1] = (merged[-1][0], run[1])
        else:
            merged.append(run)
    return merged


def recover_slot_runs(alpha: Image.Image, expected: int, threshold: int) -> list[tuple[int, int]]:
    """Split a visually separated strip at the emptiest column near each expected boundary."""
    occupancy = []
    for x in range(alpha.width):
        column = alpha.crop((x, 0, x + 1, alpha.height))
        occupancy.append(sum(1 for value in column.getdata() if value >= threshold))
    boundaries = [0]
    slot_width = alpha.width / expected
    radius = max(2, int(slot_width * 0.22))
    for index in range(1, expected):
        ideal = int(slot_width * index)
        low = max(boundaries[-1] + 1, ideal - radius)
        high = min(alpha.width - 1, ideal + radius)
        boundary = min(range(low, high + 1), key=lambda x: (occupancy[x], abs(x - ideal)))
        boundaries.append(boundary)
    boundaries.append(alpha.width)
    runs = []
    for left, right in zip(boundaries, boundaries[1:]):
        bbox = alpha.crop((left, 0, right, alpha.height)).getbbox()
        if bbox is None:
            return []
        runs.append((left + bbox[0], left + bbox[2]))
    return runs


def normalize_run_count(runs: list[tuple[int, int]], alpha: Image.Image,
                        expected: int, threshold: int) -> list[tuple[int, int]]:
    """Repair pose counting when one cat has a detached horizontal part or two poses nearly touch."""
    runs = list(runs)
    occupancy = []
    for x in range(alpha.width):
        column = alpha.crop((x, 0, x + 1, alpha.height))
        occupancy.append(sum(1 for value in column.getdata() if value >= threshold))
    while len(runs) < expected:
        index = max(range(len(runs)), key=lambda item: runs[item][1] - runs[item][0])
        left, right = runs[index]
        low = left + max(2, (right - left) // 4)
        high = right - max(2, (right - left) // 4)
        if low >= high:
            break
        cut = min(range(low, high + 1), key=lambda x: (occupancy[x], abs(x - (left + right) / 2)))
        runs[index:index + 1] = [(left, cut), (cut, right)]
    while len(runs) > expected:
        index = min(range(len(runs) - 1), key=lambda item: runs[item + 1][0] - runs[item][1])
        runs[index:index + 2] = [(runs[index][0], runs[index + 1][1])]
    return runs


def remove_tiny_islands(image: Image.Image, threshold: int) -> Image.Image:
    """Remove keying specks while preserving real separated paws and fur tufts."""
    alpha = image.getchannel("A")
    width, height = alpha.size
    occupied = [value >= threshold for value in alpha.getdata()]
    seen = bytearray(width * height)
    components: list[list[int]] = []
    for start, value in enumerate(occupied):
        if not value or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        component: list[int] = []
        while stack:
            current = stack.pop()
            component.append(current)
            x, y = current % width, current // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if occupied[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
        components.append(component)
    if not components:
        return image
    minimum = max(16, round(max(map(len, components)) * 0.002))
    removed = {index for component in components if len(component) < minimum for index in component}
    if not removed:
        return image
    pixels = list(image.getdata())
    for index in removed:
        r, g, b, _ = pixels[index]
        pixels[index] = (r, g, b, 0)
    cleaned = Image.new("RGBA", image.size)
    cleaned.putdata(pixels)
    return cleaned


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--expected", type=int, default=8)
    parser.add_argument("--start-index", type=int, default=0)
    parser.add_argument("--padding", type=int, default=24)
    parser.add_argument("--alpha-threshold", type=int, default=12)
    parser.add_argument("--min-gap", type=int, default=12)
    parser.add_argument("--uniform-slots", action="store_true",
                        help="force eight layout slots when anatomy has internal horizontal gaps")
    parser.add_argument("--component-slots", action="store_true",
                        help="group whole connected silhouettes around the expected pose centres")
    parser.add_argument("--json-out", required=True, type=Path)
    args = parser.parse_args()

    image = remove_green_key(Image.open(args.input).convert("RGBA"))
    alpha = image.getchannel("A").point(lambda value: 0 if value < args.alpha_threshold else value)
    image.putalpha(alpha)
    runs = component_slot_runs(alpha, args.expected, args.alpha_threshold) if args.component_slots else (
        [] if args.uniform_slots else occupied_runs(alpha, args.alpha_threshold, args.min_gap)
    )
    if len(runs) != args.expected:
        recovered = normalize_run_count(runs, alpha, args.expected, args.alpha_threshold) if runs else []
        if len(recovered) != args.expected:
            recovered = recover_slot_runs(alpha, args.expected, args.alpha_threshold)
        if len(recovered) != args.expected:
            raise SystemExit(f"expected {args.expected} separated pose groups, detected {len(runs)}: {runs}")
        runs = recovered

    args.output_dir.mkdir(parents=True, exist_ok=True)
    frames = []
    for index, (left, right) in enumerate(runs):
        region_alpha = alpha.crop((left, 0, right, image.height))
        local_bbox = region_alpha.getbbox()
        if local_bbox is None:
            raise SystemExit(f"pose {index} is empty")
        content_source_bbox = (
            left + local_bbox[0],
            local_bbox[1],
            left + local_bbox[2],
            local_bbox[3],
        )
        content = remove_tiny_islands(image.crop(content_source_bbox), args.alpha_threshold)
        frame = Image.new(
            "RGBA",
            (content.width + args.padding * 2, content.height + args.padding * 2),
            (0, 0, 0, 0),
        )
        frame.alpha_composite(content, (args.padding, args.padding))
        output = args.output_dir / f"{args.start_index + index:03d}.png"
        frame.save(output, optimize=True)
        content_bbox = frame.getchannel("A").getbbox()
        frames.append({
            "index": args.start_index + index,
            "image": str(output),
            "sourceStripRect": {"x": content_source_bbox[0], "y": content_source_bbox[1], "width": content.width, "height": content.height},
            "contentRect": {"x": content_bbox[0], "y": content_bbox[1], "width": content_bbox[2] - content_bbox[0], "height": content_bbox[3] - content_bbox[1]},
            "pixelScaleChanged": False,
        })

    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps({"ok": True, "sourceSize": list(image.size), "frames": frames}, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
