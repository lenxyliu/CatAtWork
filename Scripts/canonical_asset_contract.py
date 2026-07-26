#!/usr/bin/env python3
"""Canonical format-2 pet authoring and source-to-atlas validation."""

from __future__ import annotations

import hashlib
import json
import math
import re
import shutil
import struct
from pathlib import Path
from typing import Any

from PIL import Image


CANONICAL_FORMAT_VERSION = 2
CANONICAL_PIXELS_PER_BODY_UNIT = 220
CANONICAL_COLOR_SPACE = {
    "name": "sRGB",
    "pixelFormat": "RGBA8",
    "alphaMode": "straight",
    "conversion": "identity",
}
POSES = {"seated", "standing", "lying", "hanging", "airborne"}
NUMBERED_FRAME = re.compile(r"^[0-9]{3}\.png$")
IDENTIFIER = re.compile(r"^[A-Za-z][A-Za-z0-9_-]{0,63}$")
DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")
ISSUE = re.compile(r"^#[1-9][0-9]*$")
REQUIRED_LANDMARKS = {
    "leftEyeCenter",
    "rightEyeCenter",
    "leftEarRoot",
    "rightEarRoot",
    "nose",
    "mouth",
    "shoulder",
    "hip",
    "leftForelimbJoint",
    "rightForelimbJoint",
    "leftHindlimbJoint",
    "rightHindlimbJoint",
    "tailRoot",
}
REQUIRED_CONTOURS = {"headOutline", "faceMaskOutline"}


class CanonicalAssetContractError(ValueError):
    """A canonical authoring or packaging invariant failed."""


def numbered_frame_paths(frame_dir: Path) -> list[Path]:
    if not frame_dir.is_dir():
        return []
    pngs = sorted(frame_dir.glob("*.png"))
    invalid = [path.name for path in pngs if NUMBERED_FRAME.fullmatch(path.name) is None]
    if invalid:
        raise CanonicalAssetContractError(
            f"non-frame PNGs in {frame_dir}: {', '.join(invalid)}"
        )
    expected = [f"{index:03d}.png" for index in range(len(pngs))]
    actual = [path.name for path in pngs]
    if actual != expected:
        raise CanonicalAssetContractError(
            f"non-contiguous frame numbering in {frame_dir}: expected {expected}, got {actual}"
        )
    return pngs


def canonical_rgba_digest(image: Image.Image) -> str:
    """Hash dimensions plus straight, row-major RGBA8 bytes."""
    if image.mode != "RGBA":
        raise CanonicalAssetContractError("canonical digest requires RGBA8 pixels")
    payload = struct.pack(">II", image.width, image.height) + image.tobytes()
    return "sha256:" + hashlib.sha256(payload).hexdigest()


def _point(value: Any, context: str, canvas: dict[str, int]) -> dict[str, float]:
    if not isinstance(value, dict) or set(value) != {"x", "y"}:
        raise CanonicalAssetContractError(f"{context} must contain only x and y")
    if any(
        isinstance(value[axis], bool) or not isinstance(value[axis], (int, float))
        for axis in ("x", "y")
    ):
        raise CanonicalAssetContractError(f"{context} must be numeric")
    x = float(value["x"])
    y = float(value["y"])
    if not math.isfinite(x) or not math.isfinite(y):
        raise CanonicalAssetContractError(f"{context} must be finite")
    if not (0 <= x <= canvas["width"] and 0 <= y <= canvas["height"]):
        raise CanonicalAssetContractError(f"{context} lies outside the authored canvas")
    return {"x": x, "y": y}


def _rect(value: Any, context: str, canvas: dict[str, int]) -> dict[str, int]:
    if not isinstance(value, dict) or set(value) != {"x", "y", "width", "height"}:
        raise CanonicalAssetContractError(
            f"{context} must contain only x, y, width and height"
        )
    if any(isinstance(value[key], bool) or not isinstance(value[key], int) for key in value):
        raise CanonicalAssetContractError(f"{context} must contain integer coordinates")
    result = dict(value)
    if (
        result["x"] < 0
        or result["y"] < 0
        or result["width"] <= 0
        or result["height"] <= 0
        or result["x"] + result["width"] > canvas["width"]
        or result["y"] + result["height"] > canvas["height"]
    ):
        raise CanonicalAssetContractError(f"{context} lies outside the authored canvas")
    return result


def _offset(value: Any, context: str, canvas: dict[str, int]) -> dict[str, float]:
    if not isinstance(value, dict) or set(value) != {"x", "y"}:
        raise CanonicalAssetContractError(f"{context} must contain only x and y")
    if any(
        isinstance(value[axis], bool) or not isinstance(value[axis], (int, float))
        for axis in ("x", "y")
    ):
        raise CanonicalAssetContractError(f"{context} must be numeric")
    x = float(value["x"])
    y = float(value["y"])
    if (
        not math.isfinite(x)
        or not math.isfinite(y)
        or abs(x) > canvas["width"] * 4
        or abs(y) > canvas["height"] * 4
    ):
        raise CanonicalAssetContractError(f"{context} exceeds the render-offset budget")
    return {"x": x, "y": y}


def _validate_canvas(value: Any) -> dict[str, int]:
    if not isinstance(value, dict) or set(value) != {"width", "height", "safeMargin"}:
        raise CanonicalAssetContractError(
            "authoredCanvas must contain width, height and safeMargin"
        )
    if any(isinstance(value[key], bool) or not isinstance(value[key], int) for key in value):
        raise CanonicalAssetContractError("authoredCanvas values must be integers")
    canvas = dict(value)
    if canvas["width"] <= 0 or canvas["height"] <= 0 or canvas["safeMargin"] < 1:
        raise CanonicalAssetContractError("authoredCanvas values must be positive")
    if canvas["safeMargin"] * 2 >= min(canvas["width"], canvas["height"]):
        raise CanonicalAssetContractError("authoredCanvas safeMargin consumes the canvas")
    return canvas


def _validate_identity_rig(value: Any, canvas: dict[str, int]) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {"views"}:
        raise CanonicalAssetContractError("identityRig must contain only views")
    views = value["views"]
    if not isinstance(views, list) or not views:
        raise CanonicalAssetContractError("identityRig.views must not be empty")
    seen: set[str] = set()
    normalized: list[dict[str, Any]] = []
    for index, view in enumerate(views):
        context = f"identityRig.views[{index}]"
        required = {
            "id",
            "referenceAnimation",
            "referenceFrame",
            "landmarks",
            "contours",
            "materialROIs",
        }
        if not isinstance(view, dict) or set(view) != required:
            raise CanonicalAssetContractError(f"{context} has incomplete metadata")
        view_id = view["id"]
        if not isinstance(view_id, str) or IDENTIFIER.fullmatch(view_id) is None:
            raise CanonicalAssetContractError(f"{context}.id is invalid")
        if view_id in seen:
            raise CanonicalAssetContractError(f"duplicate identity view: {view_id}")
        seen.add(view_id)
        if (
            not isinstance(view["referenceAnimation"], str)
            or IDENTIFIER.fullmatch(view["referenceAnimation"]) is None
            or isinstance(view["referenceFrame"], bool)
            or not isinstance(view["referenceFrame"], int)
            or view["referenceFrame"] < 0
        ):
            raise CanonicalAssetContractError(f"{context} has an invalid reference frame")
        landmarks = view["landmarks"]
        if not isinstance(landmarks, dict) or not REQUIRED_LANDMARKS.issubset(landmarks):
            missing = sorted(REQUIRED_LANDMARKS - set(landmarks or {}))
            raise CanonicalAssetContractError(
                f"{context} is missing identity landmarks: {', '.join(missing)}"
            )
        normalized_landmarks = {
            name: _point(point, f"{context}.landmarks.{name}", canvas)
            for name, point in sorted(landmarks.items())
        }
        contours = view["contours"]
        if not isinstance(contours, dict) or not REQUIRED_CONTOURS.issubset(contours):
            missing = sorted(REQUIRED_CONTOURS - set(contours or {}))
            raise CanonicalAssetContractError(
                f"{context} is missing contours: {', '.join(missing)}"
            )
        normalized_contours: dict[str, list[dict[str, float]]] = {}
        for name, points in sorted(contours.items()):
            if not isinstance(points, list) or len(points) < 3:
                raise CanonicalAssetContractError(
                    f"{context}.contours.{name} needs at least three points"
                )
            normalized_contours[name] = [
                _point(point, f"{context}.contours.{name}[{point_index}]", canvas)
                for point_index, point in enumerate(points)
            ]
        rois = view["materialROIs"]
        if not isinstance(rois, dict) or not rois:
            raise CanonicalAssetContractError(f"{context}.materialROIs must not be empty")
        normalized_rois = {
            name: _rect(rect, f"{context}.materialROIs.{name}", canvas)
            for name, rect in sorted(rois.items())
        }
        normalized.append(
            {
                "id": view_id,
                "referenceAnimation": view["referenceAnimation"],
                "referenceFrame": view["referenceFrame"],
                "landmarks": normalized_landmarks,
                "contours": normalized_contours,
                "materialROIs": normalized_rois,
            }
        )
    return {"views": normalized}


def _validate_component_policy(value: Any) -> dict[str, Any]:
    required = {
        "default",
        "alphaThreshold",
        "minimumArea",
        "connectivity",
        "exceptions",
    }
    if not isinstance(value, dict) or set(value) != required:
        raise CanonicalAssetContractError("componentPolicy has incomplete metadata")
    if value["default"] != "forbid":
        raise CanonicalAssetContractError("componentPolicy.default must be forbid")
    if (
        isinstance(value["alphaThreshold"], bool)
        or not isinstance(value["alphaThreshold"], int)
        or not 1 <= value["alphaThreshold"] <= 255
        or isinstance(value["minimumArea"], bool)
        or not isinstance(value["minimumArea"], int)
        or value["minimumArea"] < 1
        or value["connectivity"] != 8
    ):
        raise CanonicalAssetContractError("componentPolicy thresholds are invalid")
    exceptions = value["exceptions"]
    if not isinstance(exceptions, list):
        raise CanonicalAssetContractError("componentPolicy.exceptions must be an array")
    normalized_exceptions: list[dict[str, Any]] = []
    seen: set[str] = set()
    exception_keys = {
        "reviewId",
        "issue",
        "owner",
        "reviewedBy",
        "reason",
        "animation",
        "frames",
        "maximumSecondaryComponents",
        "maximumSecondaryArea",
    }
    for index, exception in enumerate(exceptions):
        context = f"componentPolicy.exceptions[{index}]"
        if not isinstance(exception, dict) or set(exception) != exception_keys:
            raise CanonicalAssetContractError(f"{context} has incomplete review metadata")
        review_id = exception["reviewId"]
        if (
            not isinstance(review_id, str)
            or not review_id
            or review_id in seen
            or not isinstance(exception["issue"], str)
            or ISSUE.fullmatch(exception["issue"]) is None
            or not all(
                isinstance(exception[field], str) and exception[field].strip()
                for field in ("owner", "reviewedBy", "reason")
            )
            or not isinstance(exception["animation"], str)
            or IDENTIFIER.fullmatch(exception["animation"]) is None
            or not isinstance(exception["frames"], list)
            or not exception["frames"]
            or any(
                isinstance(frame, bool) or not isinstance(frame, int) or frame < 0
                for frame in exception["frames"]
            )
            or isinstance(exception["maximumSecondaryComponents"], bool)
            or not isinstance(exception["maximumSecondaryComponents"], int)
            or exception["maximumSecondaryComponents"] < 1
            or isinstance(exception["maximumSecondaryArea"], bool)
            or not isinstance(exception["maximumSecondaryArea"], int)
            or exception["maximumSecondaryArea"] < value["minimumArea"]
        ):
            raise CanonicalAssetContractError(f"{context} has invalid review metadata")
        seen.add(review_id)
        normalized_exceptions.append(
            {**exception, "frames": sorted(set(exception["frames"]))}
        )
    return {**value, "exceptions": normalized_exceptions}


def _connected_component_areas(
    alpha: Image.Image, threshold: int, minimum_area: int
) -> list[int]:
    pixels = alpha.load()
    width, height = alpha.size
    seen = bytearray(width * height)
    areas: list[int] = []
    for y in range(height):
        for x in range(width):
            position = y * width + x
            if seen[position] or pixels[x, y] < threshold:
                continue
            seen[position] = 1
            stack = [(x, y)]
            area = 0
            while stack:
                current_x, current_y = stack.pop()
                area += 1
                for next_y in range(max(0, current_y - 1), min(height, current_y + 2)):
                    for next_x in range(max(0, current_x - 1), min(width, current_x + 2)):
                        next_position = next_y * width + next_x
                        if (
                            not seen[next_position]
                            and pixels[next_x, next_y] >= threshold
                        ):
                            seen[next_position] = 1
                            stack.append((next_x, next_y))
            if area >= minimum_area:
                areas.append(area)
    return sorted(areas, reverse=True)


def _approved_component_exception(
    policy: dict[str, Any], animation: str, frame_index: int, areas: list[int]
) -> str | None:
    secondary = areas[1:]
    if not secondary:
        return None
    matches = [
        exception
        for exception in policy["exceptions"]
        if exception["animation"] == animation and frame_index in exception["frames"]
    ]
    if len(matches) != 1:
        return None
    exception = matches[0]
    if (
        len(secondary) > exception["maximumSecondaryComponents"]
        or max(secondary) > exception["maximumSecondaryArea"]
    ):
        return None
    return exception["reviewId"]


def _load_canonical_image(
    source: Path,
    canvas: dict[str, int],
    policy: dict[str, Any],
    animation: str,
    frame_index: int,
) -> tuple[Image.Image, tuple[int, int, int, int], str, str | None]:
    with Image.open(source) as opened:
        if opened.mode != "RGBA":
            raise CanonicalAssetContractError(f"{source}: source must be RGBA8")
        if opened.info.get("icc_profile"):
            raise CanonicalAssetContractError(
                f"{source}: embedded ICC profiles are forbidden; input is declared sRGB"
            )
        image = opened.copy()
    if image.size != (canvas["width"], canvas["height"]):
        raise CanonicalAssetContractError(
            f"{source}: expected fixed authored canvas "
            f"{canvas['width']}x{canvas['height']}, got {image.width}x{image.height}"
        )
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise CanonicalAssetContractError(f"empty frame: {source}")
    margin = canvas["safeMargin"]
    if (
        bbox[0] < margin
        or bbox[1] < margin
        or canvas["width"] - bbox[2] < margin
        or canvas["height"] - bbox[3] < margin
    ):
        raise CanonicalAssetContractError(f"{source}: alpha violates the safe margin")
    areas = _connected_component_areas(
        image.getchannel("A"),
        policy["alphaThreshold"],
        policy["minimumArea"],
    )
    if not areas:
        raise CanonicalAssetContractError(f"{source}: no visible material component")
    review_id = _approved_component_exception(policy, animation, frame_index, areas)
    if len(areas) > 1 and review_id is None:
        raise CanonicalAssetContractError(
            f"{animation} frame {frame_index}: disconnected components are forbidden"
        )
    return image, bbox, canonical_rgba_digest(image), review_id


def _frame_metadata(
    value: Any, context: str, canvas: dict[str, int]
) -> tuple[dict[str, float], list[dict[str, Any]]]:
    if not isinstance(value, dict) or set(value) != {"rootAnchor", "supportAnchors"}:
        raise CanonicalAssetContractError(
            f"{context} must contain rootAnchor and supportAnchors"
        )
    root = _point(value["rootAnchor"], f"{context}.rootAnchor", canvas)
    supports = value["supportAnchors"]
    if not isinstance(supports, list) or not supports:
        raise CanonicalAssetContractError(f"{context}.supportAnchors must not be empty")
    normalized: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, support in enumerate(supports):
        support_context = f"{context}.supportAnchors[{index}]"
        if not isinstance(support, dict) or set(support) != {"id", "point", "contact"}:
            raise CanonicalAssetContractError(f"{support_context} has invalid metadata")
        identifier = support["id"]
        if (
            not isinstance(identifier, str)
            or IDENTIFIER.fullmatch(identifier) is None
            or identifier in seen
            or not isinstance(support["contact"], bool)
        ):
            raise CanonicalAssetContractError(f"{support_context} has invalid metadata")
        seen.add(identifier)
        normalized.append(
            {
                "id": identifier,
                "point": _point(support["point"], f"{support_context}.point", canvas),
                "contact": support["contact"],
            }
        )
    return root, normalized


def _pack_exact(images: list[Image.Image], output: Path) -> list[tuple[int, int, int, int]]:
    max_width = 4_096
    gap = 4
    positions: list[tuple[int, int, int, int]] = []
    x = y = row_height = used_width = 0
    for image in images:
        if image.width > max_width:
            raise CanonicalAssetContractError(
                f"frame wider than atlas limit: {image.width}px"
            )
        if x and x + image.width > max_width:
            y += row_height + gap
            x = 0
            row_height = 0
        positions.append((x, y, image.width, image.height))
        x += image.width + gap
        used_width = max(used_width, x - gap)
        row_height = max(row_height, image.height)
    used_height = y + row_height
    if used_height > 8_192:
        raise CanonicalAssetContractError(
            f"atlas exceeds 8192px height: {used_height}px"
        )
    atlas = Image.new("RGBA", (used_width, used_height), (0, 0, 0, 0))
    for image, (position_x, position_y, _, _) in zip(images, positions):
        atlas.paste(image, (position_x, position_y))
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, optimize=True)
    return positions


def _pose_signature(
    pose: str, frame_index: int, frame: dict[str, Any]
) -> dict[str, Any]:
    return {
        "pose": pose,
        "frameIndex": frame_index,
        "pixelSHA256": frame["atlasPixelSHA256"],
        "rootAnchor": frame["rootAnchor"],
        "supportAnchorIDs": sorted(
            support["id"] for support in frame["supportAnchors"] if support["contact"]
        ),
    }


def _build_frame_set(
    *,
    paths: list[Path],
    metadata: list[Any],
    animation: str,
    atlas_relative: Path,
    output: Path,
    canvas: dict[str, int],
    policy: dict[str, Any],
    fps: float,
    render_offsets: list[Any] | None = None,
    hold_start_ms: float = 0,
    hold_end_ms: float = 0,
) -> list[dict[str, Any]]:
    if len(metadata) != len(paths):
        raise CanonicalAssetContractError(
            f"{animation}: frameMetadata has {len(metadata)} entries for {len(paths)} frames"
        )
    if render_offsets is not None and len(render_offsets) != len(paths):
        raise CanonicalAssetContractError(
            f"{animation}: renderOffsets has {len(render_offsets)} entries for {len(paths)} frames"
        )
    images: list[Image.Image] = []
    prepared: list[dict[str, Any]] = []
    for frame_index, (source, authored_metadata) in enumerate(zip(paths, metadata)):
        root, supports = _frame_metadata(
            authored_metadata, f"{animation}.frameMetadata[{frame_index}]", canvas
        )
        image, bbox, source_digest, review_id = _load_canonical_image(
            source, canvas, policy, animation, frame_index
        )
        images.append(image)
        frame: dict[str, Any] = {
            "image": str(atlas_relative),
            "sourceSize": {"width": canvas["width"], "height": canvas["height"]},
            "trimRect": {
                "x": bbox[0],
                "y": bbox[1],
                "width": bbox[2] - bbox[0],
                "height": bbox[3] - bbox[1],
            },
            "collisionRect": {
                "x": bbox[0],
                "y": bbox[1],
                "width": bbox[2] - bbox[0],
                "height": bbox[3] - bbox[1],
            },
            "pivot": {
                "x": root["x"] / canvas["width"],
                "y": root["y"] / canvas["height"],
            },
            "rootAnchor": root,
            "supportAnchors": supports,
            "duration": 1 / fps
            + (hold_start_ms / 1_000 if frame_index == 0 else 0)
            + (hold_end_ms / 1_000 if frame_index == len(paths) - 1 else 0),
            "sourcePixelSHA256": source_digest,
            "atlasPixelSHA256": source_digest,
        }
        if review_id is not None:
            frame["componentExceptionReviewId"] = review_id
        if render_offsets is not None:
            frame["renderOffset"] = _offset(
                render_offsets[frame_index],
                f"{animation}.renderOffsets[{frame_index}]",
                canvas,
            )
        prepared.append(frame)
    positions = _pack_exact(images, output / atlas_relative)
    with Image.open(output / atlas_relative) as opened_atlas:
        atlas = opened_atlas.convert("RGBA")
        for frame, position, source_digest in zip(prepared, positions, (
            frame["sourcePixelSHA256"] for frame in prepared
        )):
            x, y, width, height = position
            atlas_crop = atlas.crop((x, y, x + width, y + height))
            atlas_digest = canonical_rgba_digest(atlas_crop)
            if atlas_digest != source_digest:
                raise CanonicalAssetContractError(
                    f"{animation}: source-to-atlas pixel round-trip changed content"
                )
            frame["textureRect"] = {
                "x": x,
                "y": y,
                "width": width,
                "height": height,
            }
            frame["atlasPixelSHA256"] = atlas_digest
    return prepared


def build_canonical_package(
    assets_root: Path,
    output: Path,
    *,
    require_all: bool = False,
) -> dict[str, Any]:
    spec_path = assets_root / "animation-spec.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    if spec.get("contractVersion") != CANONICAL_FORMAT_VERSION:
        raise CanonicalAssetContractError(
            "canonical authoring requires contractVersion 2"
        )
    if spec.get("pixelsPerBodyUnit") != CANONICAL_PIXELS_PER_BODY_UNIT:
        raise CanonicalAssetContractError(
            f"pixelsPerBodyUnit must be {CANONICAL_PIXELS_PER_BODY_UNIT}"
        )
    if spec.get("colorSpace") != CANONICAL_COLOR_SPACE:
        raise CanonicalAssetContractError(
            "colorSpace must declare sRGB RGBA8 straight-alpha identity conversion"
        )
    canvas = _validate_canvas(spec.get("authoredCanvas"))
    policy = _validate_component_policy(spec.get("componentPolicy"))
    identity_rig = _validate_identity_rig(spec.get("identityRig"), canvas)
    actions = spec.get("actions")
    if not isinstance(actions, list) or not actions:
        raise CanonicalAssetContractError("actions must not be empty")
    if output.suffix != ".catpet" or output.name in {"", ".", ".."}:
        raise CanonicalAssetContractError("canonical output must be a named .catpet directory")
    if output.is_symlink():
        raise CanonicalAssetContractError("canonical output may not be a symbolic link")

    complete: list[tuple[dict[str, Any], list[Path]]] = []
    missing: list[str] = []
    seen_actions: set[str] = set()
    minimum_frames = int(spec.get("minimumFramesPerAnimation", 24))
    for action in actions:
        if not isinstance(action, dict):
            raise CanonicalAssetContractError("action entries must be objects")
        forbidden = {"authoringScale", "bodyScale", "pivotMode"} & set(action)
        if forbidden:
            raise CanonicalAssetContractError(
                f"{action.get('id', '<unknown>')}: canonical actions forbid "
                + ", ".join(sorted(forbidden))
            )
        action_id = action.get("id")
        if (
            not isinstance(action_id, str)
            or IDENTIFIER.fullmatch(action_id) is None
            or action_id in seen_actions
        ):
            raise CanonicalAssetContractError(f"invalid or duplicate action id: {action_id}")
        seen_actions.add(action_id)
        if action.get("startPose") not in POSES or action.get("endPose") not in POSES:
            raise CanonicalAssetContractError(f"{action_id}: invalid endpoint pose")
        if not isinstance(action.get("loop"), bool):
            raise CanonicalAssetContractError(f"{action_id}: loop must be Boolean")
        fps = action.get("fps")
        if (
            isinstance(fps, bool)
            or not isinstance(fps, (int, float))
            or not math.isfinite(float(fps))
            or not 1 <= float(fps) <= 120
        ):
            raise CanonicalAssetContractError(f"{action_id}: invalid fps")
        paths = numbered_frame_paths(assets_root / "frames" / action_id)
        if len(paths) < minimum_frames:
            missing.append(f"{action_id} ({len(paths)}/{minimum_frames})")
            continue
        complete.append((action, paths))
    if require_all and missing:
        raise CanonicalAssetContractError("incomplete animations: " + ", ".join(missing))
    if not complete:
        raise CanonicalAssetContractError("no complete animations")
    complete_ids = {action["id"] for action, _ in complete}
    if "idle" not in complete_ids:
        raise CanonicalAssetContractError("canonical package requires idle")
    for action, paths in complete:
        next_animation = action.get(
            "nextAnimation", None if action["loop"] else "idle"
        )
        if next_animation is not None and next_animation not in complete_ids:
            raise CanonicalAssetContractError(
                f"{action['id']}: nextAnimation references unavailable {next_animation}"
            )
        loop_start = action.get("loopStartFrame")
        if (
            loop_start is not None
            and (
                isinstance(loop_start, bool)
                or not isinstance(loop_start, int)
                or not 0 <= loop_start < len(paths)
            )
        ):
            raise CanonicalAssetContractError(
                f"{action['id']}: loopStartFrame is invalid"
            )

    for view in identity_rig["views"]:
        reference = next(
            (
                paths
                for action, paths in complete
                if action["id"] == view["referenceAnimation"]
            ),
            None,
        )
        if reference is None or view["referenceFrame"] >= len(reference):
            raise CanonicalAssetContractError(
                f"identity view {view['id']} references an unavailable frame"
            )

    if output.exists():
        raise CanonicalAssetContractError(
            "canonical output already exists; refusing a silent rewrite"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    build_output = output.with_name(f".{output.name}.staging")
    if build_output.exists():
        raise CanonicalAssetContractError(
            f"canonical staging path already exists: {build_output.name}"
        )
    build_output.mkdir()

    animations: list[dict[str, Any]] = []
    for action, paths in complete:
        action_id = action["id"]
        frames = _build_frame_set(
            paths=paths,
            metadata=action.get("frameMetadata"),
            animation=action_id,
            atlas_relative=Path("atlases") / f"{action_id}.png",
            output=build_output,
            canvas=canvas,
            policy=policy,
            fps=float(action["fps"]),
            render_offsets=action.get("renderOffsets"),
            hold_start_ms=float(action.get("holdStartMs", 0)),
            hold_end_ms=float(action.get("holdEndMs", 0)),
        )
        animation = {
            "id": action_id,
            "loopMode": "loop" if action.get("loop") else "once",
            "nextAnimation": action.get(
                "nextAnimation", None if action.get("loop") else "idle"
            ),
            "startPose": action["startPose"],
            "endPose": action["endPose"],
            "startPoseSignature": _pose_signature(action["startPose"], 0, frames[0]),
            "endPoseSignature": _pose_signature(
                action["endPose"], len(frames) - 1, frames[-1]
            ),
            "loopStartFrame": action.get("loopStartFrame"),
            "frames": frames,
        }
        animations.append(animation)

    look_directions: list[dict[str, Any]] = []
    look_sources = sorted((assets_root / "frames" / "lookDirections").glob("*.png"))
    if look_sources:
        if len(look_sources) != 16:
            raise CanonicalAssetContractError(
                f"look direction library must contain 16 frames, found {len(look_sources)}"
            )
        look_metadata = spec.get("lookDirectionMetadata")
        look_frames = _build_frame_set(
            paths=look_sources,
            metadata=look_metadata,
            animation="lookDirections",
            atlas_relative=Path("atlases/lookDirections.png"),
            output=build_output,
            canvas=canvas,
            policy=policy,
            fps=24,
        )
        look_directions = [
            {"degrees": index * 22.5, "frame": frame}
            for index, frame in enumerate(look_frames)
        ]

    thumbnail = assets_root / "identity" / "thumbnail.png"
    if not thumbnail.exists():
        thumbnail = assets_root / "identity" / "canonical-turnaround.png"
    if thumbnail.exists():
        shutil.copy2(thumbnail, build_output / "thumbnail.png")
    manifest = {
        "formatVersion": CANONICAL_FORMAT_VERSION,
        "id": spec["petId"],
        "displayName": spec["displayName"],
        "author": spec.get("author", "猫上班了"),
        "description": spec.get("description", ""),
        "minimumAppVersion": spec.get("minimumAppVersion", "1.0.0"),
        "assetVersion": spec.get("assetVersion", "development"),
        "pixelsPerBodyUnit": CANONICAL_PIXELS_PER_BODY_UNIT,
        "authoredCanvas": canvas,
        "colorSpace": CANONICAL_COLOR_SPACE,
        "componentPolicy": policy,
        "identityRig": identity_rig,
        "animations": animations,
        "lookDirections": look_directions,
    }
    manifest_bytes = (
        json.dumps(
            manifest,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")
    (build_output / "manifest.json").write_bytes(manifest_bytes)
    validate_canonical_package(build_output / "manifest.json")
    build_output.rename(output)
    return {
        "output": str(output),
        "complete": len(complete),
        "missing": missing,
        "manifestSHA256": hashlib.sha256(manifest_bytes).hexdigest(),
    }


def validate_canonical_package(manifest_path: Path) -> dict[str, Any]:
    """Validate a packaged format-2 manifest and every referenced atlas crop."""
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("formatVersion") != CANONICAL_FORMAT_VERSION:
        raise CanonicalAssetContractError("canonical package requires formatVersion 2")
    if manifest.get("pixelsPerBodyUnit") != CANONICAL_PIXELS_PER_BODY_UNIT:
        raise CanonicalAssetContractError(
            f"pixelsPerBodyUnit must be {CANONICAL_PIXELS_PER_BODY_UNIT}"
        )
    if manifest.get("colorSpace") != CANONICAL_COLOR_SPACE:
        raise CanonicalAssetContractError("canonical package colorSpace is invalid")
    canvas = _validate_canvas(manifest.get("authoredCanvas"))
    policy = _validate_component_policy(manifest.get("componentPolicy"))
    identity_rig = _validate_identity_rig(manifest.get("identityRig"), canvas)
    animations = manifest.get("animations")
    if not isinstance(animations, list) or not animations:
        raise CanonicalAssetContractError("canonical package animations are missing")
    root = manifest_path.parent
    atlases: dict[str, Image.Image] = {}
    reviewed_bindings: set[tuple[str, int, str]] = set()
    frame_count = 0

    def validate_frame(frame: Any, animation: str, frame_index: int) -> dict[str, Any]:
        nonlocal frame_count
        if not isinstance(frame, dict):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: frame metadata is invalid"
            )
        required = {
            "image",
            "sourceSize",
            "trimRect",
            "textureRect",
            "collisionRect",
            "pivot",
            "rootAnchor",
            "supportAnchors",
            "duration",
            "sourcePixelSHA256",
            "atlasPixelSHA256",
        }
        if not required.issubset(frame):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: canonical metadata is incomplete"
            )
        if frame.get("bodyScale") not in (None, 1, 1.0):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: bodyScale must be absent or 1"
            )
        if frame["sourceSize"] != {
            "width": canvas["width"],
            "height": canvas["height"],
        }:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: sourceSize differs from authoredCanvas"
            )
        root_anchor, supports = _frame_metadata(
            {
                "rootAnchor": frame["rootAnchor"],
                "supportAnchors": frame["supportAnchors"],
            },
            f"{animation}.frames[{frame_index}]",
            canvas,
        )
        expected_pivot = {
            "x": root_anchor["x"] / canvas["width"],
            "y": root_anchor["y"] / canvas["height"],
        }
        try:
            pivot_delta = max(
                abs(float(frame["pivot"]["x"]) - expected_pivot["x"]),
                abs(float(frame["pivot"]["y"]) - expected_pivot["y"]),
            )
        except (KeyError, TypeError, ValueError) as error:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: pivot is invalid"
            ) from error
        if pivot_delta > 1e-9:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: pivot is not the normalized root"
            )
        source_digest = frame["sourcePixelSHA256"]
        atlas_digest = frame["atlasPixelSHA256"]
        if (
            not isinstance(source_digest, str)
            or not isinstance(atlas_digest, str)
            or not is_canonical_digest(source_digest)
            or source_digest != atlas_digest
        ):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: pixel digests are invalid"
            )
        image_path = frame["image"]
        if (
            not isinstance(image_path, str)
            or not image_path
            or image_path.startswith(("/", "~"))
            or "\\" in image_path
            or ".." in Path(image_path).parts
        ):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: atlas path is unsafe"
            )
        atlas_path = root / image_path
        if image_path not in atlases:
            if not atlas_path.is_file():
                raise CanonicalAssetContractError(f"missing atlas: {image_path}")
            with Image.open(atlas_path) as opened:
                if opened.mode != "RGBA":
                    raise CanonicalAssetContractError(
                        f"{image_path}: canonical atlas must be RGBA8"
                    )
                atlases[image_path] = opened.copy()
        texture = frame["textureRect"]
        if (
            not isinstance(texture, dict)
            or set(texture) != {"x", "y", "width", "height"}
            or texture["width"] != canvas["width"]
            or texture["height"] != canvas["height"]
            or texture["x"] < 0
            or texture["y"] < 0
            or texture["x"] + texture["width"] > atlases[image_path].width
            or texture["y"] + texture["height"] > atlases[image_path].height
        ):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: textureRect is invalid"
            )
        crop = atlases[image_path].crop(
            (
                texture["x"],
                texture["y"],
                texture["x"] + texture["width"],
                texture["y"] + texture["height"],
            )
        )
        if canonical_rgba_digest(crop) != atlas_digest:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: atlas pixels do not match the digest"
            )
        bbox = crop.getchannel("A").getbbox()
        if bbox is None:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: atlas crop is empty"
            )
        margin = canvas["safeMargin"]
        if (
            bbox[0] < margin
            or bbox[1] < margin
            or canvas["width"] - bbox[2] < margin
            or canvas["height"] - bbox[3] < margin
        ):
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: atlas alpha violates the safe margin"
            )
        areas = _connected_component_areas(
            crop.getchannel("A"),
            policy["alphaThreshold"],
            policy["minimumArea"],
        )
        review_id = _approved_component_exception(
            policy, animation, frame_index, areas
        )
        declared_review = frame.get("componentExceptionReviewId")
        if len(areas) > 1 and review_id is None:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: disconnected components are forbidden"
            )
        if declared_review != review_id:
            raise CanonicalAssetContractError(
                f"{animation} frame {frame_index}: component review binding is invalid"
            )
        if review_id is not None:
            reviewed_bindings.add((animation, frame_index, review_id))
        frame_count += 1
        return {
            "rootAnchor": root_anchor,
            "supportAnchorIDs": sorted(
                support["id"] for support in supports if support["contact"]
            ),
            "pixelSHA256": atlas_digest,
        }

    by_action: dict[str, list[dict[str, Any]]] = {}
    for animation in animations:
        action_id = animation.get("id") if isinstance(animation, dict) else None
        if not isinstance(action_id, str) or IDENTIFIER.fullmatch(action_id) is None:
            raise CanonicalAssetContractError("canonical package action id is invalid")
        if action_id in by_action:
            raise CanonicalAssetContractError(f"duplicate action: {action_id}")
        if animation.get("startPose") not in POSES or animation.get("endPose") not in POSES:
            raise CanonicalAssetContractError(f"{action_id}: invalid endpoint pose")
        frames = animation.get("frames")
        if not isinstance(frames, list) or not frames:
            raise CanonicalAssetContractError(f"{action_id}: frames are missing")
        summaries = [
            validate_frame(frame, action_id, frame_index)
            for frame_index, frame in enumerate(frames)
        ]
        by_action[action_id] = summaries
        for name, expected_index, expected_pose, summary in (
            ("startPoseSignature", 0, animation["startPose"], summaries[0]),
            (
                "endPoseSignature",
                len(summaries) - 1,
                animation["endPose"],
                summaries[-1],
            ),
        ):
            signature = animation.get(name)
            if (
                not isinstance(signature, dict)
                or signature.get("pose") != expected_pose
                or signature.get("frameIndex") != expected_index
                or signature.get("pixelSHA256") != summary["pixelSHA256"]
                or signature.get("rootAnchor") != summary["rootAnchor"]
                or signature.get("supportAnchorIDs") != summary["supportAnchorIDs"]
            ):
                raise CanonicalAssetContractError(
                    f"{action_id}: {name} does not bind the actual endpoint"
                )

    look_directions = manifest.get("lookDirections")
    if not isinstance(look_directions, list):
        raise CanonicalAssetContractError("lookDirections must be an array")
    for frame_index, direction in enumerate(look_directions):
        if (
            not isinstance(direction, dict)
            or set(direction) != {"degrees", "frame"}
            or float(direction["degrees"]) != frame_index * 22.5
        ):
            raise CanonicalAssetContractError("lookDirections metadata is invalid")
        validate_frame(direction["frame"], "lookDirections", frame_index)

    for view in identity_rig["views"]:
        if (
            view["referenceAnimation"] not in by_action
            or view["referenceFrame"]
            >= len(by_action[view["referenceAnimation"]])
        ):
            raise CanonicalAssetContractError(
                f"identity view {view['id']} references an unavailable frame"
            )
    expected_bindings = {
        (exception["animation"], frame_index, exception["reviewId"])
        for exception in policy["exceptions"]
        for frame_index in exception["frames"]
    }
    if reviewed_bindings != expected_bindings:
        raise CanonicalAssetContractError(
            "componentPolicy exceptions do not exactly match reviewed frame content"
        )
    return {
        "formatVersion": CANONICAL_FORMAT_VERSION,
        "frameCount": frame_count,
        "atlasCount": len(atlases),
    }


def is_canonical_digest(value: str) -> bool:
    return DIGEST.fullmatch(value) is not None
