#!/usr/bin/env python3
"""Deterministic baseline and release visual-QA hard gates."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
import statistics
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, __version__ as pillow_version


TOOL_NAME = "catatwork-visual-qa"
TOOL_VERSION = "1.0.0"
REPORT_SCHEMA = "catatwork.visual-qa-report/v1"
CONTRACT_SCHEMA = "catatwork.visual-qa-contract/v1"
SUPPLEMENTAL_SCHEMA = "catatwork.visual-qa-supplemental/v1"
ALPHA_THRESHOLD = 12
CORE_ALPHA_THRESHOLD = 160


def canonical_bytes(value: Any, *, pretty: bool = False) -> bytes:
    separators = None if pretty else (",", ":")
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=2 if pretty else None,
        separators=separators,
        sort_keys=True,
    )
    return (text + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_digest(root: Path) -> str:
    lines = []
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        relative = path.relative_to(root).as_posix()
        lines.append(f"{sha256_file(path)}  ./{relative}\n")
    return sha256_bytes("".join(lines).encode("utf-8"))


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def round_number(value: float, digits: int = 6) -> float:
    result = round(float(value), digits)
    return 0.0 if result == -0.0 else result


def image_digest(image: Image.Image, channel: str = "RGBA") -> str:
    selected = image.convert("RGBA") if channel == "RGBA" else image.getchannel(channel)
    prefix = f"{selected.width}x{selected.height}:{channel}:".encode("ascii")
    return sha256_bytes(prefix + selected.tobytes())


def crop_frame(atlas: Image.Image, frame: dict[str, Any]) -> Image.Image:
    rect = frame.get("textureRect")
    if rect is None:
        return atlas.convert("RGBA")
    return atlas.crop(
        (
            int(rect["x"]),
            int(rect["y"]),
            int(rect["x"] + rect["width"]),
            int(rect["y"] + rect["height"]),
        )
    ).convert("RGBA")


def alpha_geometry(image: Image.Image, frame: dict[str, Any]) -> dict[str, Any] | None:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return None
    pixels = list(alpha.getdata())
    width = image.width
    count = 0
    sum_x = 0.0
    sum_y = 0.0
    for offset, value in enumerate(pixels):
        if value >= ALPHA_THRESHOLD:
            count += 1
            sum_x += offset % width
            sum_y += offset // width
    scale = float(frame.get("bodyScale", 1.0))
    pivot = frame["pivot"]
    render_offset = frame.get("renderOffset") or {"x": 0, "y": 0}
    root_x = float(pivot["x"]) * image.width - float(render_offset["x"])
    root_y = float(pivot["y"]) * image.height - float(render_offset["y"])
    return {
        "bbox": bbox,
        "width": bbox[2] - bbox[0],
        "height": bbox[3] - bbox[1],
        "area": count,
        "centroidX": (sum_x / count - root_x) * scale,
        "centroidY": (sum_y / count - root_y) * scale,
        "supportY": (bbox[3] - root_y) * scale,
        "edgeClearance": min(bbox[0], bbox[1], image.width - bbox[2], image.height - bbox[3]),
    }


def connected_components(image: Image.Image) -> list[dict[str, int]]:
    alpha = list(image.getchannel("A").getdata())
    width, height = image.size
    occupied = [value >= ALPHA_THRESHOLD for value in alpha]
    seen = bytearray(width * height)
    components: list[dict[str, int]] = []
    for start, present in enumerate(occupied):
        if not present or seen[start]:
            continue
        seen[start] = 1
        stack = [start]
        count = 0
        peak = 0
        while stack:
            current = stack.pop()
            count += 1
            peak = max(peak, alpha[current])
            x, y = current % width, current // width
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    if nx == x and ny == y:
                        continue
                    neighbor = ny * width + nx
                    if occupied[neighbor] and not seen[neighbor]:
                        seen[neighbor] = 1
                        stack.append(neighbor)
        components.append({"area": count, "peakAlpha": peak})
    return sorted(components, key=lambda item: (-item["area"], -item["peakAlpha"]))


def srgb_to_lab(red: int, green: int, blue: int) -> tuple[float, float, float]:
    def linear(channel: int) -> float:
        value = channel / 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    r, g, b = linear(red), linear(green), linear(blue)
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b)
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    def pivot(value: float) -> float:
        delta = 6 / 29
        return value ** (1 / 3) if value > delta**3 else value / (3 * delta**2) + 4 / 29

    fx, fy, fz = pivot(x), pivot(y), pivot(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def ciede2000(first: tuple[float, float, float], second: tuple[float, float, float]) -> float:
    l1, a1, b1 = first
    l2, a2, b2 = second
    c1 = math.hypot(a1, b1)
    c2 = math.hypot(a2, b2)
    average_c = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt((average_c**7) / (average_c**7 + 25**7)))
    a1_prime = (1 + g) * a1
    a2_prime = (1 + g) * a2
    c1_prime = math.hypot(a1_prime, b1)
    c2_prime = math.hypot(a2_prime, b2)

    def hue(a_value: float, b_value: float) -> float:
        angle = math.degrees(math.atan2(b_value, a_value))
        return angle + 360 if angle < 0 else angle

    h1_prime = hue(a1_prime, b1)
    h2_prime = hue(a2_prime, b2)
    delta_l = l2 - l1
    delta_c = c2_prime - c1_prime
    hue_delta = h2_prime - h1_prime
    if c1_prime * c2_prime == 0:
        delta_h_angle = 0
    elif abs(hue_delta) <= 180:
        delta_h_angle = hue_delta
    elif hue_delta > 180:
        delta_h_angle = hue_delta - 360
    else:
        delta_h_angle = hue_delta + 360
    delta_h = 2 * math.sqrt(c1_prime * c2_prime) * math.sin(math.radians(delta_h_angle / 2))
    mean_l = (l1 + l2) / 2
    mean_c = (c1_prime + c2_prime) / 2
    if c1_prime * c2_prime == 0:
        mean_h = h1_prime + h2_prime
    elif abs(h1_prime - h2_prime) <= 180:
        mean_h = (h1_prime + h2_prime) / 2
    elif h1_prime + h2_prime < 360:
        mean_h = (h1_prime + h2_prime + 360) / 2
    else:
        mean_h = (h1_prime + h2_prime - 360) / 2
    t = (
        1
        - 0.17 * math.cos(math.radians(mean_h - 30))
        + 0.24 * math.cos(math.radians(2 * mean_h))
        + 0.32 * math.cos(math.radians(3 * mean_h + 6))
        - 0.20 * math.cos(math.radians(4 * mean_h - 63))
    )
    sl = 1 + (0.015 * (mean_l - 50) ** 2) / math.sqrt(20 + (mean_l - 50) ** 2)
    sc = 1 + 0.045 * mean_c
    sh = 1 + 0.015 * mean_c * t
    delta_theta = 30 * math.exp(-((mean_h - 275) / 25) ** 2)
    rc = 2 * math.sqrt((mean_c**7) / (mean_c**7 + 25**7))
    rt = -rc * math.sin(math.radians(2 * delta_theta))
    return math.sqrt(
        (delta_l / sl) ** 2
        + (delta_c / sc) ** 2
        + (delta_h / sh) ** 2
        + rt * (delta_c / sc) * (delta_h / sh)
    )


def material_labs(image: Image.Image) -> dict[str, tuple[float, float, float] | None]:
    sample = image.copy()
    sample.thumbnail((128, 128), Image.Resampling.NEAREST)
    groups: dict[str, list[tuple[float, float, float]]] = {
        "light": [],
        "warm": [],
        "dark": [],
    }
    for red, green, blue, alpha in sample.getdata():
        if alpha < CORE_ALPHA_THRESHOLD:
            continue
        lab = srgb_to_lab(red, green, blue)
        if lab[0] >= 72:
            groups["light"].append(lab)
        if lab[0] <= 38:
            groups["dark"].append(lab)
        if red >= green + 8 and green >= blue:
            groups["warm"].append(lab)
    result: dict[str, tuple[float, float, float] | None] = {}
    for name, values in groups.items():
        if len(values) < 8:
            result[name] = None
        else:
            result[name] = tuple(statistics.median(component) for component in zip(*values))
    return result


def identity_proxy(image: Image.Image, geometry: dict[str, Any]) -> dict[str, float]:
    bbox = geometry["bbox"]
    alpha = image.getchannel("A")
    top_end = bbox[1] + max(1, round((bbox[3] - bbox[1]) * 0.42))
    widths = []
    dark_pixels = 0
    rgb = image.convert("RGB")
    for y in range(bbox[1], top_end):
        xs = [x for x in range(bbox[0], bbox[2]) if alpha.getpixel((x, y)) >= ALPHA_THRESHOLD]
        if xs:
            widths.append(max(xs) - min(xs) + 1)
        for x in xs:
            red, green, blue = rgb.getpixel((x, y))
            if max(red, green, blue) <= 105:
                dark_pixels += 1
    return {
        "upperSilhouetteWidth": statistics.median(widths) if widths else 0,
        "upperDarkSupport": dark_pixels,
    }


def compile_action_contracts(contract: dict[str, Any], action_ids: Iterable[str]) -> dict[str, dict[str, Any]]:
    compiled: dict[str, dict[str, Any]] = {}
    for group in contract.get("actionContracts", []):
        required = {
            "name",
            "actions",
            "thresholdProfile",
            "squashStretch",
            "airborneMovement",
            "supportPhases",
            "allowedDisconnectedComponents",
        }
        missing = sorted(required - set(group))
        if missing:
            raise ValueError(f"action contract {group.get('name', '<unnamed>')} missing {missing}")
        for action in group["actions"]:
            if action in compiled:
                raise ValueError(f"action {action} appears in more than one action contract")
            compiled[action] = group
    expected = set(action_ids)
    actual = set(compiled)
    if expected != actual:
        raise ValueError(
            f"action contracts do not exactly cover manifest actions; missing={sorted(expected-actual)}, "
            f"unexpected={sorted(actual-expected)}"
        )
    return compiled


def validate_waivers(waivers: list[dict[str, Any]], *, today: date | None = None) -> dict[str, dict[str, Any]]:
    required = {
        "id",
        "issue",
        "rationale",
        "owner",
        "affectedActions",
        "affectedFrames",
        "expiryDate",
    }
    today = today or date.today()
    result = {}
    for waiver in waivers:
        missing = sorted(required - set(waiver))
        if missing:
            raise ValueError(f"waiver missing required fields: {missing}")
        if not str(waiver["issue"]).startswith(("ISSUE-", "https://github.com/")):
            raise ValueError(f"waiver {waiver['id']} has invalid Issue identity")
        if not waiver["rationale"] or not waiver["owner"]:
            raise ValueError(f"waiver {waiver['id']} requires rationale and owner")
        if not isinstance(waiver["affectedActions"], list) or not waiver["affectedActions"]:
            raise ValueError(f"waiver {waiver['id']} requires affected actions")
        if not isinstance(waiver["affectedFrames"], list) or not waiver["affectedFrames"]:
            raise ValueError(f"waiver {waiver['id']} requires affected frames")
        expiry = date.fromisoformat(waiver["expiryDate"])
        if expiry < today:
            raise ValueError(f"waiver {waiver['id']} expired on {expiry.isoformat()}")
        if waiver["id"] in result:
            raise ValueError(f"duplicate waiver id {waiver['id']}")
        result[waiver["id"]] = waiver
    return result


def observation(
    *,
    observation_id: str,
    finding_id: str,
    family: str,
    metric: str,
    value: Any,
    comparison: str,
    threshold: Any,
    threshold_source: str,
    severity: str = "error",
    action: str | None = None,
    frames: list[int] | None = None,
    waiver_id: str | None = None,
) -> dict[str, Any]:
    item = {
        "observationId": observation_id,
        "findingId": finding_id,
        "family": family,
        "metric": metric,
        "value": value,
        "comparison": comparison,
        "threshold": threshold,
        "thresholdSource": threshold_source,
        "severity": severity,
    }
    if action is not None:
        item["action"] = action
    if frames is not None:
        item["frames"] = frames
    if waiver_id is not None:
        item["waiverId"] = waiver_id
    return item


def observation_passes(item: dict[str, Any]) -> bool:
    value = item["value"]
    threshold = item["threshold"]
    comparison = item["comparison"]
    if comparison == "lte":
        return value <= threshold
    if comparison == "gte":
        return value >= threshold
    if comparison == "eq":
        return value == threshold
    if comparison == "between":
        return threshold[0] <= value <= threshold[1]
    if comparison == "zero":
        return value == 0
    if comparison == "true":
        return value is True
    if comparison == "false":
        return value is False
    raise ValueError(f"unsupported comparison {comparison}")


def waiver_covers(waiver: dict[str, Any], item: dict[str, Any]) -> bool:
    action = item.get("action")
    frames = item.get("frames") or []
    action_ok = "*" in waiver["affectedActions"] or action in waiver["affectedActions"]
    frame_keys = {f"{action}:{frame}" for frame in frames}
    frame_ok = "*" in waiver["affectedFrames"] or not frames or frame_keys <= set(waiver["affectedFrames"])
    return action_ok and frame_ok


def evaluate_observations(
    *,
    mode: str,
    observations: list[dict[str, Any]],
    expected_failure_ids: list[str],
    waivers: list[dict[str, Any]],
    package: dict[str, Any],
    input_digests: dict[str, str],
    tool_versions: dict[str, str] | None = None,
) -> dict[str, Any]:
    waiver_map = validate_waivers(waivers)
    seen_observation_ids: set[str] = set()
    normalized = []
    violations: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in sorted(observations, key=lambda entry: entry["observationId"]):
        if item["observationId"] in seen_observation_ids:
            raise ValueError(f"duplicate observation id {item['observationId']}")
        seen_observation_ids.add(item["observationId"])
        passed = observation_passes(item)
        normalized_item = dict(item)
        normalized_item["passed"] = passed
        normalized.append(normalized_item)
        if passed:
            continue
        waiver_id = item.get("waiverId")
        waived = False
        if waiver_id is not None:
            if item["severity"] == "error":
                raise ValueError(f"error observation {item['observationId']} cannot be waived")
            waiver = waiver_map.get(waiver_id)
            if waiver is None or not waiver_covers(waiver, item):
                raise ValueError(f"waiver {waiver_id} does not cover {item['observationId']}")
            waived = True
        violation = {
            "observationId": item["observationId"],
            "severity": item["severity"],
            "waived": waived,
        }
        if waiver_id is not None:
            violation["waiverId"] = waiver_id
        violations[item["findingId"]].append(violation)

    findings = []
    for finding_id in sorted(violations):
        entries = violations[finding_id]
        severity = "error" if any(entry["severity"] == "error" for entry in entries) else "warning"
        findings.append(
            {
                "findingId": finding_id,
                "severity": severity,
                "waived": all(entry["waived"] for entry in entries),
                "violations": entries,
            }
        )
    actual_ids = sorted(finding["findingId"] for finding in findings if not finding["waived"])
    expected_ids = sorted(expected_failure_ids)
    new_ids = sorted(set(actual_ids) - set(expected_ids))
    missing_ids = sorted(set(expected_ids) - set(actual_ids))
    errors = [finding for finding in findings if finding["severity"] == "error" and not finding["waived"]]
    warnings = [finding for finding in findings if finding["severity"] == "warning" and not finding["waived"]]
    if mode == "baseline":
        decision = not new_ids and not missing_ids
    elif mode == "release":
        decision = not errors and not warnings
    else:
        raise ValueError(f"unsupported mode {mode}")
    versions = tool_versions or {
        "visualQa": TOOL_VERSION,
        "python": platform.python_version(),
        "pillow": pillow_version,
    }
    content_digest = sha256_bytes(
        canonical_bytes(
            {
                "inputDigests": input_digests,
                "package": package,
                "toolVersions": versions,
            }
        )
    )
    return {
        "schemaVersion": REPORT_SCHEMA,
        "mode": mode,
        "decision": "pass" if decision else "fail",
        "contentDigest": content_digest,
        "toolVersions": versions,
        "package": package,
        "inputDigests": dict(sorted(input_digests.items())),
        "summary": {
            "observationCount": len(normalized),
            "findingCount": len(findings),
            "errorCount": len(errors),
            "unwaivedWarningCount": len(warnings),
            "waivedFindingCount": sum(1 for finding in findings if finding["waived"]),
        },
        "baselineComparison": {
            "expectedFindingIds": expected_ids,
            "actualFindingIds": actual_ids,
            "newFindingIds": new_ids,
            "missingFindingIds": missing_ids,
        },
        "waivers": sorted(waivers, key=lambda waiver: waiver["id"]),
        "findings": findings,
        "observations": normalized,
    }


def add_pair_observations(
    observations: list[dict[str, Any]],
    *,
    action: str,
    first_index: int,
    second_index: int,
    seam: str,
    first: dict[str, Any],
    second: dict[str, Any],
    profile: dict[str, Any],
    threshold_source: str,
) -> None:
    prefix = f"static/{action}/{first_index + 1:03d}-{second_index + 1:03d}/{seam}"
    metrics = {
        "widthRatio": max(first["width"], second["width"]) / max(1, min(first["width"], second["width"])),
        "heightRatio": max(first["height"], second["height"]) / max(1, min(first["height"], second["height"])),
        "areaRatio": max(first["area"], second["area"]) / max(1, min(first["area"], second["area"])),
        "rootCentroidDeltaPixels": math.hypot(
            second["centroidX"] - first["centroidX"],
            second["centroidY"] - first["centroidY"],
        ),
        "supportDeltaPixels": abs(second["supportY"] - first["supportY"]),
    }
    thresholds = {
        "widthRatio": profile["adjacentWidthRatio"],
        "heightRatio": profile["adjacentHeightRatio"],
        "areaRatio": profile["adjacentAreaRatio"],
        "rootCentroidDeltaPixels": profile["rootCentroidDeltaPixels"],
        "supportDeltaPixels": profile["supportDeltaPixels"],
    }
    findings = {
        "rootCentroidDeltaPixels": "ISSUE-018/root-support",
        "supportDeltaPixels": "ISSUE-018/root-support",
    }
    for metric, value in metrics.items():
        finding_id = findings.get(metric, "ISSUE-015/adjacent-continuity")
        observations.append(
            observation(
                observation_id=f"{prefix}/{metric}",
                finding_id=finding_id,
                family=f"{seam}Continuity",
                metric=metric,
                value=round_number(value),
                comparison="lte",
                threshold=thresholds[metric],
                threshold_source=threshold_source,
                action=action,
                frames=[first_index + 1, second_index + 1],
            )
        )
    for material in ("light", "warm", "dark"):
        first_lab = first["materials"].get(material)
        second_lab = second["materials"].get(material)
        if first_lab is None or second_lab is None:
            continue
        observations.append(
            observation(
                observation_id=f"{prefix}/material-{material}-deltaE00",
                finding_id="ISSUE-016/material-color",
                family="materialColor",
                metric=f"{material}DeltaE00",
                value=round_number(ciede2000(first_lab, second_lab), 4),
                comparison="lte",
                threshold=profile["materialDeltaE00"],
                threshold_source=threshold_source,
                action=action,
                frames=[first_index + 1, second_index + 1],
            )
        )


def scan_static(
    *,
    manifest: dict[str, Any],
    package_root: Path,
    source_root: Path,
    contract: dict[str, Any],
) -> list[dict[str, Any]]:
    observations: list[dict[str, Any]] = []
    action_ids = [animation["id"] for animation in manifest.get("animations", [])]
    action_contracts = compile_action_contracts(contract, action_ids)
    profiles = contract["thresholdProfiles"]
    atlas_cache: dict[Path, Image.Image] = {}
    action_frames: dict[str, list[dict[str, Any]]] = {}
    for animation in manifest.get("animations", []):
        action = animation["id"]
        semantic = action_contracts[action]
        profile = profiles[semantic["thresholdProfile"]]
        source_dir = source_root / "frames" / action
        frame_metrics = []
        for index, frame in enumerate(animation.get("frames", [])):
            atlas_path = package_root / frame["image"]
            if atlas_path not in atlas_cache:
                atlas_cache[atlas_path] = Image.open(atlas_path).convert("RGBA")
            image = crop_frame(atlas_cache[atlas_path], frame)
            source_path = source_dir / f"{index:03d}.png"
            source = Image.open(source_path).convert("RGBA") if source_path.is_file() else None
            frame_id = f"{action}:{index + 1}"
            if source is None:
                observations.append(
                    observation(
                        observation_id=f"static/{frame_id}/source-present",
                        finding_id="ISSUE-017/source-atlas-round-trip",
                        family="sourceAtlasRoundTrip",
                        metric="sourcePresent",
                        value=False,
                        comparison="true",
                        threshold=True,
                        threshold_source="ADR-0015/source-atlas-round-trip",
                        action=action,
                        frames=[index + 1],
                    )
                )
            else:
                same_size = source.size == image.size
                observations.append(
                    observation(
                        observation_id=f"static/{frame_id}/source-size",
                        finding_id="ISSUE-017/source-atlas-round-trip",
                        family="sourceAtlasRoundTrip",
                        metric="samePixelDimensions",
                        value=same_size,
                        comparison="true",
                        threshold=True,
                        threshold_source="ADR-0015/source-atlas-round-trip",
                        action=action,
                        frames=[index + 1],
                    )
                )
                observations.append(
                    observation(
                        observation_id=f"static/{frame_id}/rgba-digest",
                        finding_id="ISSUE-017/source-atlas-round-trip",
                        family="sourceAtlasRoundTrip",
                        metric="rgbaDigestMatch",
                        value=same_size and image_digest(source) == image_digest(image),
                        comparison="true",
                        threshold=True,
                        threshold_source="ADR-0015/source-atlas-round-trip",
                        action=action,
                        frames=[index + 1],
                    )
                )
                observations.append(
                    observation(
                        observation_id=f"static/{frame_id}/alpha-digest",
                        finding_id="ISSUE-017/source-atlas-round-trip",
                        family="sourceAtlasRoundTrip",
                        metric="alphaDigestMatch",
                        value=same_size and image_digest(source, "A") == image_digest(image, "A"),
                        comparison="true",
                        threshold=True,
                        threshold_source="ADR-0015/source-atlas-round-trip",
                        action=action,
                        frames=[index + 1],
                    )
                )
            geometry = alpha_geometry(image, frame)
            if geometry is None:
                observations.append(
                    observation(
                        observation_id=f"static/{frame_id}/nonempty",
                        finding_id="ISSUE-015/adjacent-continuity",
                        family="alphaGeometry",
                        metric="nonempty",
                        value=False,
                        comparison="true",
                        threshold=True,
                        threshold_source="ADR-0015/nonempty-frame",
                        action=action,
                        frames=[index + 1],
                    )
                )
                continue
            components = connected_components(image)
            significant = [
                item
                for item in components[1:]
                if item["area"] >= contract["componentPolicy"]["minimumArea"]
                and item["peakAlpha"] >= contract["componentPolicy"]["minimumPeakAlpha"]
            ]
            allowed = semantic["allowedDisconnectedComponents"]
            observations.append(
                observation(
                    observation_id=f"static/{frame_id}/components",
                    finding_id="ISSUE-021/connected-components",
                    family="connectedComponents",
                    metric="unapprovedSignificantComponents",
                    value=max(0, len(significant) - len(allowed)),
                    comparison="zero",
                    threshold=0,
                    threshold_source="ADR-0015/component-policy",
                    action=action,
                    frames=[index + 1],
                )
            )
            observations.append(
                observation(
                    observation_id=f"static/{frame_id}/edge-clearance",
                    finding_id="ISSUE-015/edge-clearance",
                    family="edgeClearance",
                    metric="minimumTransparentMarginPixels",
                    value=geometry["edgeClearance"],
                    comparison="gte",
                    threshold=profile["edgeClearancePixels"],
                    threshold_source=f"contract/thresholdProfiles/{semantic['thresholdProfile']}",
                    action=action,
                    frames=[index + 1],
                )
            )
            geometry["materials"] = material_labs(image)
            geometry["identity"] = identity_proxy(image, geometry)
            frame_metrics.append(geometry)
        action_frames[action] = frame_metrics
        for index in range(len(frame_metrics) - 1):
            seam = "batchSeam" if index in {7, 15} else "adjacent"
            add_pair_observations(
                observations,
                action=action,
                first_index=index,
                second_index=index + 1,
                seam=seam,
                first=frame_metrics[index],
                second=frame_metrics[index + 1],
                profile=profile,
                threshold_source=f"contract/thresholdProfiles/{semantic['thresholdProfile']}",
            )
        if animation.get("loopMode") == "loop" and len(frame_metrics) > 1:
            loop_start = int(animation.get("loopStartFrame") or 0)
            loop_start = min(max(loop_start, 0), len(frame_metrics) - 1)
            add_pair_observations(
                observations,
                action=action,
                first_index=len(frame_metrics) - 1,
                second_index=loop_start,
                seam="loopSeam",
                first=frame_metrics[-1],
                second=frame_metrics[loop_start],
                profile=profile,
                threshold_source=f"contract/thresholdProfiles/{semantic['thresholdProfile']}",
            )
        for metric in ("width", "height", "area", "centroidX", "centroidY"):
            values = [float(item[metric]) for item in frame_metrics]
            median = max(1.0, abs(statistics.median(values)))
            for index in range(1, len(values) - 1):
                second_difference = abs(values[index + 1] - 2 * values[index] + values[index - 1]) / median
                observations.append(
                    observation(
                        observation_id=f"static/{action}/{index + 1:03d}/second-difference-{metric}",
                        finding_id="ISSUE-015/adjacent-continuity",
                        family="secondDifference",
                        metric=metric,
                        value=round_number(second_difference),
                        comparison="lte",
                        threshold=profile["secondDifferenceRatio"],
                        threshold_source=f"contract/thresholdProfiles/{semantic['thresholdProfile']}",
                        action=action,
                        frames=[index, index + 1, index + 2],
                    )
                )

    comparable: dict[str, list[tuple[str, int, dict[str, Any]]]] = defaultdict(list)
    for animation in manifest.get("animations", []):
        frames = action_frames.get(animation["id"], [])
        if not frames:
            continue
        comparable[str(animation.get("startPose"))].append((animation["id"], 1, frames[0]))
        comparable[str(animation.get("endPose"))].append((animation["id"], len(frames), frames[-1]))
    identity_thresholds = contract["identityPolicy"]
    for pose, endpoints in sorted(comparable.items()):
        if pose in {"None", "airborne", "hanging"} or len(endpoints) < 2:
            continue
        widths = [entry[2]["identity"]["upperSilhouetteWidth"] for entry in endpoints]
        dark_supports = [entry[2]["identity"]["upperDarkSupport"] for entry in endpoints]
        median_width = max(1.0, statistics.median(widths))
        median_dark = max(1.0, statistics.median(dark_supports))
        for action, frame, metrics in endpoints:
            width_deviation = abs(metrics["identity"]["upperSilhouetteWidth"] / median_width - 1)
            dark_deviation = abs(metrics["identity"]["upperDarkSupport"] / median_dark - 1)
            observations.append(
                observation(
                    observation_id=f"static/{pose}/{action}:{frame}/cross-action-scale",
                    finding_id="ISSUE-017/cross-action-scale",
                    family="canonicalScale",
                    metric="upperSilhouetteRelativeDeviation",
                    value=round_number(width_deviation),
                    comparison="lte",
                    threshold=identity_thresholds["headScaleDeviation"],
                    threshold_source="contract/identityPolicy/headScaleDeviation",
                    action=action,
                    frames=[frame],
                )
            )
            observations.append(
                observation(
                    observation_id=f"static/{pose}/{action}:{frame}/identity-dark-support",
                    finding_id="ISSUE-026/identity-proxy",
                    family="canonicalIdentity",
                    metric="upperDarkSupportRelativeDeviation",
                    value=round_number(dark_deviation),
                    comparison="lte",
                    threshold=identity_thresholds["darkSupportDeviation"],
                    threshold_source="contract/identityPolicy/darkSupportDeviation",
                    action=action,
                    frames=[frame],
                )
            )
    return observations


def supplemental_observations(data: dict[str, Any]) -> list[dict[str, Any]]:
    if data.get("schemaVersion") != SUPPLEMENTAL_SCHEMA:
        raise ValueError(f"supplemental evidence must use {SUPPLEMENTAL_SCHEMA}")
    results: list[dict[str, Any]] = []
    endpoint = data["endpointPose"]
    results.append(
        observation(
            observation_id="supplemental/endpoint-pose/coverage",
            finding_id="ISSUE-022/endpoint-pose",
            family="endpointPose",
            metric="reviewedEndpointCount",
            value=endpoint["reviewedEndpointCount"],
            comparison="gte",
            threshold=endpoint["requiredEndpointCount"],
            threshold_source=endpoint["thresholdSource"],
        )
    )
    results.append(
        observation(
            observation_id="supplemental/endpoint-pose/mismatches",
            finding_id="ISSUE-022/endpoint-pose",
            family="endpointPose",
            metric="mismatchCount",
            value=len(endpoint["mismatches"]),
            comparison="zero",
            threshold=0,
            threshold_source=endpoint["thresholdSource"],
        )
    )
    for index, case in enumerate(data["locomotion"]["cases"]):
        prefix = f"supplemental/locomotion/{index:02d}-{case['id']}"
        fields = (
            ("nearZeroDurationMilliseconds", "lte", 100),
            ("distanceRatio", "between", [0.9, 1.1]),
            ("strideErrorRatio", "lte", 0.05),
            ("supportSlipPixels", "lte", 2),
            ("directionMatches", "true", True),
        )
        for metric, comparison, threshold in fields:
            results.append(
                observation(
                    observation_id=f"{prefix}/{metric}",
                    finding_id="ISSUE-019/locomotion",
                    family="locomotion",
                    metric=metric,
                    value=case[metric],
                    comparison=comparison,
                    threshold=threshold,
                    threshold_source=data["locomotion"]["thresholdSource"],
                    action=case["action"],
                    frames=case.get("frames"),
                )
            )
    for index, sample in enumerate(data["cadence"]["samples"]):
        refresh_period = 1000 / sample["refreshHz"]
        results.append(
            observation(
                observation_id=f"supplemental/cadence/{index:02d}/frame-duration-error",
                finding_id="ISSUE-023/cadence",
                family="cadence",
                metric="maximumFrameDurationErrorMilliseconds",
                value=sample["maximumFrameDurationErrorMilliseconds"],
                comparison="lte",
                threshold=round_number(refresh_period),
                threshold_source=data["cadence"]["thresholdSource"],
                action=sample["action"],
            )
        )
        results.append(
            observation(
                observation_id=f"supplemental/cadence/{index:02d}/phase-drift",
                finding_id="ISSUE-023/cadence",
                family="cadence",
                metric="phaseDriftFramesAt60Seconds",
                value=sample["phaseDriftFramesAt60Seconds"],
                comparison="lte",
                threshold=1,
                threshold_source=data["cadence"]["thresholdSource"],
                action=sample["action"],
            )
        )
    for index, sample in enumerate(data["renderSnapshot"]["samples"]):
        for metric in ("transparentFrameCount", "mixedSnapshotFrameCount"):
            results.append(
                observation(
                    observation_id=f"supplemental/render-snapshot/{index:02d}/{metric}",
                    finding_id="ISSUE-024/render-snapshot",
                    family="renderSnapshot",
                    metric=metric,
                    value=sample[metric],
                    comparison="zero",
                    threshold=0,
                    threshold_source=data["renderSnapshot"]["thresholdSource"],
                )
            )
    gaze = data["gazeBody"]
    gaze_fields = (
        ("changedPixelsOutsideEyeROI", "zero", 0),
        ("bodyStateInvariant", "true", True),
        ("alphaBoundsInvariant", "true", True),
        ("additionalTextureRequestCount", "zero", 0),
    )
    for metric, comparison, threshold in gaze_fields:
        results.append(
            observation(
                observation_id=f"supplemental/gaze-body/{metric}",
                finding_id="ISSUE-025/gaze-body-orthogonality",
                family="gazeBodyOrthogonality",
                metric=metric,
                value=gaze[metric],
                comparison=comparison,
                threshold=threshold,
                threshold_source=gaze["thresholdSource"],
            )
        )
    return results


def validate_contract(contract: dict[str, Any], manifest: dict[str, Any], package_digest: str) -> None:
    if contract.get("schemaVersion") != CONTRACT_SCHEMA:
        raise ValueError(f"contract must use {CONTRACT_SCHEMA}")
    if contract["baseline"]["packageDigest"] != package_digest:
        raise ValueError("baseline package digest does not match inspected package")
    compile_action_contracts(contract, [item["id"] for item in manifest.get("animations", [])])
    validate_waivers(contract.get("waivers", []))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--supplemental", required=True, type=Path)
    parser.add_argument("--mode", choices=("baseline", "release"), required=True)
    parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = load_json(args.manifest)
    contract = load_json(args.contract)
    supplemental = load_json(args.supplemental)
    package_root = args.manifest.parent
    package_digest = tree_digest(package_root)
    validate_contract(contract, manifest, package_digest)
    if supplemental.get("packageDigest") != package_digest:
        raise ValueError("supplemental evidence package digest does not match inspected package")
    observations = scan_static(
        manifest=manifest,
        package_root=package_root,
        source_root=args.source_root,
        contract=contract,
    )
    observations.extend(supplemental_observations(supplemental))
    input_digests = {
        "manifest": sha256_file(args.manifest),
        "package": package_digest,
        "source": tree_digest(args.source_root),
        "contract": sha256_file(args.contract),
        "supplemental": sha256_file(args.supplemental),
    }
    report = evaluate_observations(
        mode=args.mode,
        observations=observations,
        expected_failure_ids=contract["baseline"]["expectedFindingIds"],
        waivers=contract.get("waivers", []),
        package={
            "id": manifest.get("id"),
            "assetVersion": manifest.get("assetVersion"),
            "packageDigest": package_digest,
            "actionCount": len(manifest.get("animations", [])),
            "frameCount": sum(len(item.get("frames", [])) for item in manifest.get("animations", [])),
        },
        input_digests=input_digests,
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_bytes(canonical_bytes(report, pretty=True))
    if report["decision"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
