#!/usr/bin/env python3
"""Fail packaging when animations are short, duplicated, clipped, or rescaled."""

from __future__ import annotations

import argparse
import hashlib
import json
import statistics
import math
from pathlib import Path

from PIL import Image


def frame_image(path: Path, frame: dict) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    rect = frame.get("textureRect")
    if rect:
        image = image.crop((rect["x"], rect["y"], rect["x"] + rect["width"], rect["y"] + rect["height"]))
    return image


def digest(image: Image.Image) -> str:
    return hashlib.sha256(image.tobytes()).hexdigest()


def largest_component_ratio(alpha: Image.Image) -> float:
    mask = alpha.copy()
    mask.thumbnail((128, 128), Image.Resampling.NEAREST)
    width, height = mask.size
    pixels = [value >= 12 for value in mask.getdata()]
    total = sum(pixels)
    if not total:
        return 0
    seen = bytearray(width * height)
    largest = 0
    for start, occupied in enumerate(pixels):
        if not occupied or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        count = 0
        while stack:
            current = stack.pop()
            count += 1
            x, y = current % width, current // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if pixels[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
        largest = max(largest, count)
    return largest / total


def canvas_layout(frames: list[dict], margin: float = 16) -> dict:
    left = right = top = bottom = 0.0
    for frame in frames:
        scale = frame.get("bodyScale", 1.0)
        width = frame["sourceSize"]["width"] * scale
        height = frame["sourceSize"]["height"] * scale
        pivot = frame["pivot"]
        offset = frame.get("renderOffset") or {"x": 0, "y": 0}
        offset_x = offset["x"] * scale
        offset_y = offset["y"] * scale
        left = max(left, pivot["x"] * width - offset_x)
        right = max(right, (1 - pivot["x"]) * width + offset_x)
        top = max(top, pivot["y"] * height - offset_y)
        bottom = max(bottom, (1 - pivot["y"]) * height + offset_y)
    return {
        "width": math.ceil(left + right + margin * 2),
        "height": math.ceil(top + bottom + margin * 2),
        "anchorX": margin + left,
        "anchorYFromTop": margin + top,
        "margin": margin,
    }


def placement(frame: dict, layout: dict) -> tuple[float, float]:
    scale = frame.get("bodyScale", 1.0)
    offset = frame.get("renderOffset") or {"x": 0, "y": 0}
    return (
        layout["anchorX"] - frame["pivot"]["x"] * frame["sourceSize"]["width"] * scale + offset["x"] * scale,
        layout["anchorYFromTop"] - frame["pivot"]["y"] * frame["sourceSize"]["height"] * scale + offset["y"] * scale,
    )


def visible_geometry(image: Image.Image, frame: dict, layout: dict) -> dict | None:
    alpha = image.getchannel("A")
    binary = alpha.point(lambda value: 255 if value >= 12 else 0)
    bbox = binary.getbbox()
    if bbox is None:
        return None
    scale = frame.get("bodyScale", 1.0)
    origin_x, origin_y = placement(frame, layout)
    count = 0
    sum_x = 0.0
    sum_y = 0.0
    for y in range(bbox[1], bbox[3]):
        for x in range(bbox[0], bbox[2]):
            if alpha.getpixel((x, y)) >= 12:
                count += 1
                sum_x += x
                sum_y += y
    return {
        "bbox": [
            origin_x + bbox[0] * scale,
            origin_y + bbox[1] * scale,
            origin_x + bbox[2] * scale,
            origin_y + bbox[3] * scale,
        ],
        "localSize": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "area": count * scale * scale,
        "centroid": [origin_x + (sum_x / count) * scale, origin_y + (sum_y / count) * scale],
    }


def pair_metric(first: dict, second: dict, first_index: int, second_index: int, pixels_per_body_unit: float) -> dict:
    width_ratio = max(first["localSize"][0], second["localSize"][0]) / max(1, min(first["localSize"][0], second["localSize"][0]))
    height_ratio = max(first["localSize"][1], second["localSize"][1]) / max(1, min(first["localSize"][1], second["localSize"][1]))
    area_ratio = max(first["area"], second["area"]) / max(1, min(first["area"], second["area"]))
    dx = second["centroid"][0] - first["centroid"][0]
    dy = second["centroid"][1] - first["centroid"][1]
    centroid_distance = math.hypot(dx, dy)
    score = centroid_distance / max(1, pixels_per_body_unit)
    score += abs(math.log(area_ratio)) + 0.5 * abs(math.log(width_ratio)) + 0.5 * abs(math.log(height_ratio))
    return {
        "from": first_index + 1,
        "to": second_index + 1,
        "phaseSeam": (first_index, second_index) in {(7, 8), (15, 16), (23, 0)},
        "centroidDeltaPixels": round(centroid_distance, 2),
        "centroidDeltaBodyUnits": round(centroid_distance / max(1, pixels_per_body_unit), 4),
        "widthRatio": round(width_ratio, 4),
        "heightRatio": round(height_ratio, 4),
        "areaRatio": round(area_ratio, 4),
        "jumpScore": round(score, 4),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    root = args.manifest.parent
    errors: list[str] = []
    animation_reports = []
    body_heights = []
    runtime_scales = set()
    all_frames = [frame for animation in manifest.get("animations", []) for frame in animation.get("frames", [])]
    all_frames += [direction["frame"] for direction in manifest.get("lookDirections", [])]
    safe_canvas = canvas_layout(all_frames)
    legacy_canvas = {
        "width": max((frame["sourceSize"]["width"] for frame in all_frames), default=320),
        "height": max((frame["sourceSize"]["height"] for frame in all_frames), default=320),
    }
    legacy_canvas.update({"anchorX": legacy_canvas["width"] / 2, "anchorYFromTop": legacy_canvas["height"] - 16})
    legacy_clipped_frames = []
    temporal_warnings = []
    pixels_per_body_unit = float(manifest.get("pixelsPerBodyUnit") or 1)
    for animation in manifest.get("animations", []):
        frames = animation.get("frames", [])
        if len(frames) < 24:
            errors.append(f"{animation['id']}: expected at least 24 frames, got {len(frames)}")
        hashes = []
        dimensions = []
        opaque_areas = []
        geometries = []
        for frame_index, frame in enumerate(frames):
            runtime_scales.add(frame.get("bodyScale", 1.0))
            path = root / frame["image"]
            if not path.is_file():
                errors.append(f"{animation['id']}: missing {frame['image']}")
                continue
            image = frame_image(path, frame)
            alpha = image.getchannel("A").point(lambda value: 255 if value >= 12 else 0)
            bbox = alpha.getbbox()
            if bbox is None:
                errors.append(f"{animation['id']}: empty {frame['image']}")
                continue
            if bbox[0] == 0 or bbox[1] == 0 or bbox[2] == image.width or bbox[3] == image.height:
                errors.append(f"{animation['id']}: content touches canvas edge in {frame['image']}")
            if bbox[2] - bbox[0] < 32 or bbox[3] - bbox[1] < 32:
                errors.append(f"{animation['id']}: invalid tiny silhouette in {frame['image']}")
            connected = largest_component_ratio(image.getchannel("A"))
            if connected < 0.45:
                errors.append(f"{animation['id']}: fragmented silhouette ({connected:.2f}) in atlas frame")
            opaque_areas.append(sum(1 for value in image.getchannel("A").getdata() if value >= 12))
            hashes.append(digest(image))
            dimensions.append([bbox[2] - bbox[0], bbox[3] - bbox[1]])
            body_heights.append(bbox[3] - bbox[1])
            geometry = visible_geometry(image, frame, safe_canvas)
            geometries.append(geometry)
            if geometry:
                old_origin_x = legacy_canvas["anchorX"] - frame["pivot"]["x"] * frame["sourceSize"]["width"] * frame.get("bodyScale", 1.0)
                old_origin_y = legacy_canvas["anchorYFromTop"] - frame["pivot"]["y"] * frame["sourceSize"]["height"] * frame.get("bodyScale", 1.0)
                old_bbox = [
                    old_origin_x + bbox[0], old_origin_y + bbox[1],
                    old_origin_x + bbox[2], old_origin_y + bbox[3],
                ]
                if old_bbox[0] < 0 or old_bbox[1] < 0 or old_bbox[2] > legacy_canvas["width"] or old_bbox[3] > legacy_canvas["height"]:
                    legacy_clipped_frames.append({"animation": animation["id"], "frame": frame_index + 1, "bbox": [round(value, 2) for value in old_bbox]})
        if len(hashes) != len(set(hashes)):
            errors.append(f"{animation['id']}: byte-identical duplicate frames detected")
        if opaque_areas:
            median_area = statistics.median(opaque_areas)
            for index, area in enumerate(opaque_areas):
                if area < median_area * 0.30:
                    errors.append(f"{animation['id']}: frame {index + 1} has implausibly small visible area")
        pairs = []
        for index in range(len(geometries) - 1):
            if geometries[index] and geometries[index + 1]:
                pairs.append(pair_metric(geometries[index], geometries[index + 1], index, index + 1, pixels_per_body_unit))
        if animation.get("loopMode") == "loop" and len(geometries) > 1:
            loop_start = min(max(int(animation.get("loopStartFrame") or 0), 0), len(geometries) - 1)
            if geometries[-1] and geometries[loop_start]:
                pairs.append(pair_metric(
                    geometries[-1], geometries[loop_start],
                    len(geometries) - 1, loop_start, pixels_per_body_unit
                ))

        action_kind = animation["id"]
        micro_action = action_kind in {"idle", "idleEar", "idleTail", "sleep", "curious", "working", "waiting"}
        centroid_limit = 0.14 if micro_action else 0.38
        flagged = [pair for pair in pairs if (
            pair["centroidDeltaBodyUnits"] > centroid_limit or pair["areaRatio"] > 1.75 or
            pair["widthRatio"] > 1.65 or pair["heightRatio"] > 1.65
        )]
        if flagged:
            temporal_warnings.append({"animation": action_kind, "pairs": flagged})
        animation_reports.append({
            "id": animation["id"], "frameCount": len(frames), "uniqueFiles": len(set(hashes)),
            "contentSizes": dimensions,
            "phaseSeams": [pair for pair in pairs if pair["phaseSeam"]],
            "largestAdjacentJumps": sorted(pairs, key=lambda item: item["jumpScore"], reverse=True)[:5],
            "flaggedAdjacentJumps": flagged,
        })

    look_directions = manifest.get("lookDirections", [])
    if len(look_directions) != 16:
        errors.append(f"lookDirections: expected 16, got {len(look_directions)}")
    if sorted(direction.get("degrees") for direction in look_directions) != [index * 22.5 for index in range(16)]:
        errors.append("lookDirections: degrees must be fixed clockwise 22.5-degree increments")
    for direction in look_directions:
        path = root / direction["frame"]["image"]
        if not path.is_file():
            errors.append(f"lookDirections: missing {direction['frame']['image']}")
            continue
        image = frame_image(path, direction["frame"])
        bbox = image.getchannel("A").point(lambda value: 255 if value >= 12 else 0).getbbox()
        if bbox is None or bbox[2] - bbox[0] < 32 or bbox[3] - bbox[1] < 32:
            errors.append(f"lookDirections: invalid silhouette in {direction['frame']['image']}")

    if runtime_scales != {1.0}:
        errors.append(f"runtime bodyScale must be globally fixed at 1.0, found {sorted(runtime_scales)}")

    report = {
        "ok": not errors,
        "errors": errors,
        "pixelsPerBodyUnit": manifest.get("pixelsPerBodyUnit"),
        "runtimeBodyScales": sorted(runtime_scales),
        "safeRuntimeCanvas": safe_canvas,
        "legacyRuntimeCanvas": legacy_canvas,
        "legacyCanvasClippedFrameCount": len(legacy_clipped_frames),
        "legacyCanvasClippedFrames": legacy_clipped_frames,
        "temporalWarnings": temporal_warnings,
        "lookDirectionCount": len(look_directions),
        "observedContentHeightRange": [min(body_heights), max(body_heights)] if body_heights else None,
        "animations": animation_reports,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    if errors:
        raise SystemExit("\n".join(errors))


if __name__ == "__main__":
    main()
