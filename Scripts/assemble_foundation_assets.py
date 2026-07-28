#!/usr/bin/env python3
"""Assemble the governed B4 foundation slice without resizing pet pixels."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from PIL import Image
from validate_visual_qa import srgb_to_lab


SCHEMA = "catatwork.foundation-build/v1"
EXPECTED_SOURCE_SIZE = (1774, 887)
EXPECTED_ACTIONS = (
    "idle",
    "sitToStand",
    "standToSit",
    "lieDown",
    "getUp",
    "walkLeft",
    "walkRight",
    "runLeft",
    "runRight",
)
TAKES = {
    "idle": ("idle",),
    "sitToStand": (
        "sitToStand-key",
        "sitToStand-take2",
        "sitToStand-take3",
    ),
    "lieDown": (
        "lieDown-take1",
        "lieDown-take2",
        "lieDown-take3",
        "lieDown-take4",
        "lieDown-take5",
        "lieDown-take7",
    ),
    "walkLeft": ("walkLeft-cycle",),
    "runLeft": ("runLeft-cycle", "run-bridge-variants"),
}


class FoundationBuildError(ValueError):
    """A frozen foundation invariant failed."""


@dataclass(frozen=True)
class DraftFrame:
    take: str
    index: int
    image: Path
    source_size: tuple[int, int]
    source_rect: dict[str, int]
    grid_cell: dict[str, int]
    content_rect: dict[str, int]
    assigned_components: int
    boundary_clearance: int

    @property
    def progress(self) -> float:
        return self.content_rect["width"] / self.content_rect["height"]


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_take(draft_root: Path, take: str) -> list[DraftFrame]:
    report_path = draft_root / f"{take}.json"
    report = load_json(report_path)
    if report.get("ok") is not True:
        raise FoundationBuildError(f"{take}: extraction report is not passing")
    source_size = tuple(report.get("sourceSize") or ())
    if source_size != EXPECTED_SOURCE_SIZE:
        raise FoundationBuildError(
            f"{take}: expected source sheet {EXPECTED_SOURCE_SIZE}, got {source_size}"
        )
    frames = report.get("frames")
    if not isinstance(frames, list) or len(frames) != 8:
        raise FoundationBuildError(f"{take}: expected exactly eight extracted poses")
    result: list[DraftFrame] = []
    for expected_index, frame in enumerate(frames):
        if frame.get("index") != expected_index:
            raise FoundationBuildError(f"{take}: extraction indexes are not contiguous")
        if frame.get("pixelScaleChanged") is not False:
            raise FoundationBuildError(f"{take}: extracted pixels were resized")
        if frame.get("assignedComponents") != 1:
            raise FoundationBuildError(
                f"{take} frame {expected_index}: expected one authored pose component"
            )
        image = Path(frame["image"])
        if not image.is_file():
            raise FoundationBuildError(f"{take}: missing extracted frame {image}")
        result.append(
            DraftFrame(
                take=take,
                index=expected_index,
                image=image,
                source_size=(int(source_size[0]), int(source_size[1])),
                source_rect=dict(frame["sourceGridRect"]),
                grid_cell=dict(frame["gridCell"]),
                content_rect=dict(frame["contentRect"]),
                assigned_components=int(frame["assignedComponents"]),
                boundary_clearance=int(frame["boundaryClearance"]),
            )
        )
    return result


def connected_component_areas(
    alpha: Image.Image, *, threshold: int, minimum_area: int
) -> list[int]:
    width, height = alpha.size
    pixels = alpha.load()
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
                for next_y in range(
                    max(0, current_y - 1), min(height, current_y + 2)
                ):
                    for next_x in range(
                        max(0, current_x - 1), min(width, current_x + 2)
                    ):
                        neighbor = next_y * width + next_x
                        if (
                            not seen[neighbor]
                            and pixels[next_x, next_y] >= threshold
                        ):
                            seen[neighbor] = 1
                            stack.append((next_x, next_y))
            if area >= minimum_area:
                areas.append(area)
    return sorted(areas, reverse=True)


def alpha_centroid(image: Image.Image, *, threshold: int = 12) -> tuple[float, float]:
    alpha = list(image.getchannel("A").getdata())
    width = image.width
    occupied = [offset for offset, value in enumerate(alpha) if value >= threshold]
    if not occupied:
        raise FoundationBuildError("cannot calculate the centroid of an empty frame")
    return (
        sum(offset % width for offset in occupied) / len(occupied),
        sum(offset // width for offset in occupied) / len(occupied),
    )


def round_ratio_ties_to_even(numerator: int, denominator: int) -> int:
    quotient, remainder = divmod(numerator, denominator)
    comparison = remainder * 2 - denominator
    if comparison < 0:
        return quotient
    if comparison > 0:
        return quotient + 1
    return quotient + quotient % 2


def material_label(
    pixel: tuple[int, int, int, int],
    *,
    normalization: dict[str, Any],
    lightness_cache: dict[tuple[int, int, int], float] | None = None,
) -> str | None:
    red, green, blue, alpha = pixel
    if alpha < int(normalization["classificationAlphaMinimum"]):
        return None
    rgb = (red, green, blue)
    lightness = (
        lightness_cache.get(rgb)
        if lightness_cache is not None
        else None
    )
    if lightness is None:
        lightness = srgb_to_lab(red, green, blue)[0]
        if lightness_cache is not None:
            lightness_cache[rgb] = lightness
    if lightness <= normalization["darkMaximumLStar"]:
        return "dark"
    if lightness >= normalization["lightMinimumLStar"]:
        return "light"
    if red >= green + 8 and green >= blue:
        return "warm"
    return None


def local_material_means(
    image: Image.Image,
    *,
    labels: list[str | None],
    radius: int,
) -> list[tuple[int, int, int] | None]:
    """Return exact same-material box means without crossing material/alpha edges."""

    width, height = image.size
    pixels = list(image.getdata())
    means: list[tuple[int, int, int] | None] = [None] * len(pixels)
    stride = width + 1
    integral_size = stride * (height + 1)
    for material in ("light", "warm", "dark"):
        integrals = [[0] * integral_size for _ in range(4)]
        for y in range(height):
            row_totals = [0, 0, 0, 0]
            row_offset = y * width
            current_row = (y + 1) * stride
            previous_row = y * stride
            for x in range(width):
                offset = row_offset + x
                red, green, blue, _ = pixels[offset]
                if labels[offset] == material:
                    row_totals[0] += 1
                    row_totals[1] += red
                    row_totals[2] += green
                    row_totals[3] += blue
                for channel in range(4):
                    integrals[channel][current_row + x + 1] = (
                        integrals[channel][previous_row + x + 1]
                        + row_totals[channel]
                    )
        for y in range(height):
            top = max(0, y - radius)
            bottom = min(height, y + radius + 1)
            for x in range(width):
                offset = y * width + x
                if labels[offset] != material:
                    continue
                left = max(0, x - radius)
                right = min(width, x + radius + 1)
                top_left = top * stride + left
                top_right = top * stride + right
                bottom_left = bottom * stride + left
                bottom_right = bottom * stride + right
                totals = [
                    integral[bottom_right]
                    - integral[top_right]
                    - integral[bottom_left]
                    + integral[top_left]
                    for integral in integrals
                ]
                count = totals[0]
                if count <= 0:
                    raise FoundationBuildError(
                        "material neighborhood unexpectedly has no samples"
                    )
                means[offset] = tuple(
                    round_ratio_ties_to_even(total, count)
                    for total in totals[1:]
                )
    return means


def normalize_material_colors(
    image: Image.Image,
    *,
    material_references: dict[str, Any],
) -> Image.Image:
    """Correct material location while restoring same-material local detail."""

    normalization = material_references["normalization"]
    if (
        normalization.get("method")
        != "fixed-source-effect-detail-preserving-material-pull"
    ):
        raise FoundationBuildError("unsupported foundation material normalization")
    if normalization.get("rounding") != "nearest-integer-ties-to-even":
        raise FoundationBuildError("unsupported foundation color rounding")
    source_weight = normalization.get("sourceWeight")
    canonical_weight = normalization.get("canonicalWeight")
    detail_numerator = normalization.get("detailWeightNumerator")
    detail_denominator = normalization.get("detailWeightDenominator")
    radius = normalization.get("detailNeighborhoodRadius")
    alpha_minimum = normalization.get("classificationAlphaMinimum")
    if (
        isinstance(source_weight, bool)
        or not isinstance(source_weight, int)
        or source_weight <= 0
        or isinstance(canonical_weight, bool)
        or not isinstance(canonical_weight, int)
        or canonical_weight <= 0
    ):
        raise FoundationBuildError("foundation color weights must be positive integers")
    if (
        isinstance(detail_numerator, bool)
        or not isinstance(detail_numerator, int)
        or detail_numerator < 0
        or isinstance(detail_denominator, bool)
        or not isinstance(detail_denominator, int)
        or detail_denominator <= 0
        or detail_numerator > detail_denominator
    ):
        raise FoundationBuildError("foundation detail weight must be between zero and one")
    if isinstance(radius, bool) or not isinstance(radius, int) or radius <= 0:
        raise FoundationBuildError("foundation detail neighborhood must be positive")
    if (
        isinstance(alpha_minimum, bool)
        or not isinstance(alpha_minimum, int)
        or not 0 <= alpha_minimum <= 255
    ):
        raise FoundationBuildError("foundation classification alpha is invalid")
    total_weight = source_weight + canonical_weight
    targets = {
        "light": tuple(material_references["lightCoat"]["srgbMedian"]),
        "warm": tuple(material_references["warmCoat"]["srgbMedian"]),
        "dark": tuple(material_references["darkMask"]["srgbMedian"]),
    }
    pixels = list(image.getdata())
    lightness_cache: dict[tuple[int, int, int], float] = {}
    labels = [
        material_label(
            pixel,
            normalization=normalization,
            lightness_cache=lightness_cache,
        )
        for pixel in pixels
    ]
    local_means = local_material_means(
        image,
        labels=labels,
        radius=radius,
    )
    normalized = []
    for offset, (red, green, blue, alpha) in enumerate(pixels):
        material = labels[offset]
        if material is None:
            normalized.append((red, green, blue, alpha))
            continue
        local_mean = local_means[offset]
        if local_mean is None:
            raise FoundationBuildError("governed material pixel has no local mean")
        replacement = []
        for source, canonical, local in zip(
            (red, green, blue),
            targets[material],
            local_mean,
        ):
            base = round_ratio_ties_to_even(
                source * source_weight + canonical * canonical_weight,
                total_weight,
            )
            detail = round_ratio_ties_to_even(
                (source - local) * detail_numerator,
                detail_denominator,
            )
            replacement.append(max(0, min(255, base + detail)))
        normalized.append((*replacement, alpha))
    result = Image.new("RGBA", image.size)
    result.putdata(normalized)
    return result


def author_canvas(
    draft: DraftFrame,
    *,
    canvas: dict[str, Any],
    root: dict[str, float],
    component_policy: dict[str, Any],
    material_references: dict[str, Any],
    centroid_proxy_offset_x: float,
) -> tuple[Image.Image, dict[str, Any]]:
    with Image.open(draft.image) as opened:
        if opened.mode != "RGBA":
            raise FoundationBuildError(f"{draft.image}: extracted frame must be RGBA")
        if opened.info.get("icc_profile"):
            raise FoundationBuildError(f"{draft.image}: embedded ICC is forbidden")
        source = opened.copy()
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise FoundationBuildError(f"{draft.image}: extracted frame is empty")
    expected_bbox = (
        draft.content_rect["x"],
        draft.content_rect["y"],
        draft.content_rect["x"] + draft.content_rect["width"],
        draft.content_rect["y"] + draft.content_rect["height"],
    )
    if bbox != expected_bbox:
        raise FoundationBuildError(
            f"{draft.image}: content rectangle changed after extraction"
        )

    # The extraction grid only locates a pose; it is not an anatomical root.
    # Integer-translate the occupied-pixel centroid to the frozen horizontal
    # root proxy while keeping the lowest support pixel on the frozen support
    # line. No pet pixel is resized or resampled.
    source = normalize_material_colors(
        source,
        material_references=material_references,
    )
    local_centroid_x, local_centroid_y = alpha_centroid(source)
    paste_x = round(
        float(root["x"]) + centroid_proxy_offset_x - local_centroid_x
    )
    paste_y = round(float(root["y"]) - bbox[3])
    output = Image.new(
        "RGBA",
        (int(canvas["width"]), int(canvas["height"])),
        (0, 0, 0, 0),
    )
    if (
        paste_x < -source.width
        or paste_y < -source.height
        or paste_x + source.width > output.width + source.width
        or paste_y + source.height > output.height + source.height
    ):
        raise FoundationBuildError(f"{draft.image}: authored placement is unreasonable")
    output.paste(source, (paste_x, paste_y))
    output_bbox = output.getchannel("A").getbbox()
    if output_bbox is None:
        raise FoundationBuildError(f"{draft.image}: authored frame became empty")
    margin = int(canvas["safeMargin"])
    if (
        output_bbox[0] < margin
        or output_bbox[1] < margin
        or output.width - output_bbox[2] < margin
        or output.height - output_bbox[3] < margin
    ):
        raise FoundationBuildError(
            f"{draft.image}: authored alpha violates {margin}px safe margin"
        )
    areas = connected_component_areas(
        output.getchannel("A"),
        threshold=int(component_policy["alphaThreshold"]),
        minimum_area=int(component_policy["minimumArea"]),
    )
    if len(areas) != 1:
        raise FoundationBuildError(
            f"{draft.image}: expected one significant component, got {areas}"
        )
    return output, {
        "take": draft.take,
        "takeFrame": draft.index,
        "sourceImage": str(draft.image),
        "sourceSHA256": sha256_file(draft.image),
        "sourceGridRect": draft.source_rect,
        "gridCell": draft.grid_cell,
        "sourceAlphaCentroid": {
            "x": round(local_centroid_x, 6),
            "y": round(local_centroid_y, 6),
        },
        "authoredPlacement": {"x": paste_x, "y": paste_y},
        "materialColorNormalization": {
            "method": material_references["normalization"]["method"],
            "sourceWeight": material_references["normalization"]["sourceWeight"],
            "canonicalWeight": material_references["normalization"][
                "canonicalWeight"
            ],
            "detailNeighborhoodRadius": material_references["normalization"][
                "detailNeighborhoodRadius"
            ],
            "detailWeightNumerator": material_references["normalization"][
                "detailWeightNumerator"
            ],
            "detailWeightDenominator": material_references["normalization"][
                "detailWeightDenominator"
            ],
            "classificationAlphaMinimum": material_references["normalization"][
                "classificationAlphaMinimum"
            ],
            "perActionOrFrameTuning": False,
        },
        "authoredAlphaBounds": {
            "x": output_bbox[0],
            "y": output_bbox[1],
            "width": output_bbox[2] - output_bbox[0],
            "height": output_bbox[3] - output_bbox[1],
        },
        "pixelScaleChanged": False,
        "significantComponentAreas": areas,
    }


def transformed_point(
    point: dict[str, float],
    source_bounds: dict[str, int],
    target_bounds: tuple[int, int, int, int],
) -> dict[str, float]:
    target_x, target_y, target_right, target_bottom = target_bounds
    target_width = target_right - target_x
    target_height = target_bottom - target_y
    x_ratio = (float(point["x"]) - source_bounds["x"]) / source_bounds["width"]
    y_ratio = (float(point["y"]) - source_bounds["y"]) / source_bounds["height"]
    return {
        "x": round(target_x + x_ratio * target_width, 6),
        "y": round(target_y + y_ratio * target_height, 6),
    }


def transformed_rect(
    rect: dict[str, int],
    source_bounds: dict[str, int],
    target_bounds: tuple[int, int, int, int],
    canvas: dict[str, Any],
) -> dict[str, int]:
    top_left = transformed_point(
        {"x": rect["x"], "y": rect["y"]}, source_bounds, target_bounds
    )
    bottom_right = transformed_point(
        {"x": rect["x"] + rect["width"], "y": rect["y"] + rect["height"]},
        source_bounds,
        target_bounds,
    )
    x = max(0, min(int(canvas["width"]) - 1, round(top_left["x"])))
    y = max(0, min(int(canvas["height"]) - 1, round(top_left["y"])))
    right = max(x + 1, min(int(canvas["width"]), round(bottom_right["x"])))
    bottom = max(y + 1, min(int(canvas["height"]), round(bottom_right["y"])))
    return {"x": x, "y": y, "width": right - x, "height": bottom - y}


def identity_view(
    *,
    identifier: str,
    sheet_view: dict[str, Any],
    reference_action: str,
    reference_frame: int,
    reference_image: Image.Image,
    canvas: dict[str, Any],
) -> dict[str, Any]:
    target_bounds = reference_image.getchannel("A").getbbox()
    if target_bounds is None:
        raise FoundationBuildError(f"{identifier}: empty identity reference frame")
    source_bounds = sheet_view["bounds"]
    landmarks = {
        name: transformed_point(point, source_bounds, target_bounds)
        for name, point in sorted(sheet_view["landmarks"].items())
    }
    head = [
        landmarks["leftEarRoot"],
        landmarks["rightEarRoot"],
        landmarks["rightEyeCenter"],
        landmarks["mouth"],
        landmarks["leftEyeCenter"],
    ]
    mask = [
        landmarks["leftEyeCenter"],
        landmarks["rightEyeCenter"],
        landmarks["nose"],
        landmarks["mouth"],
        landmarks["leftEarRoot"],
    ]
    return {
        "id": identifier,
        "referenceAnimation": reference_action,
        "referenceFrame": reference_frame,
        "landmarks": landmarks,
        "contours": {
            "headOutline": head,
            "faceMaskOutline": mask,
        },
        "materialROIs": {
            name: transformed_rect(rect, source_bounds, target_bounds, canvas)
            for name, rect in sorted(sheet_view["materialROIs"].items())
        },
    }


def support_pair(
    action: str, index: int, count: int
) -> list[dict[str, Any]]:
    seated = (296.0, 369.0)
    standing_left = (194.0, 486.0)
    lying_left = (255.0, 435.0)
    if action == "idle":
        pair = seated
    elif action == "sitToStand":
        phase = index / max(1, count - 1)
        pair = tuple(
            seated[position] * (1 - phase) + standing_left[position] * phase
            for position in (0, 1)
        )
    elif action == "standToSit":
        phase = index / max(1, count - 1)
        pair = tuple(
            standing_left[position] * (1 - phase) + seated[position] * phase
            for position in (0, 1)
        )
    elif action == "lieDown":
        phase = index / max(1, count - 1)
        pair = tuple(
            seated[position] * (1 - phase) + lying_left[position] * phase
            for position in (0, 1)
        )
    elif action == "getUp":
        phase = index / max(1, count - 1)
        pair = tuple(
            lying_left[position] * (1 - phase) + seated[position] * phase
            for position in (0, 1)
        )
    elif action in {"walkLeft", "runLeft"}:
        pair = standing_left
    elif action in {"walkRight", "runRight"}:
        pair = tuple(665.0 - value for value in reversed(standing_left))
    else:
        raise FoundationBuildError(f"unsupported support action {action}")
    phase = index % 8
    left_contact = phase in {0, 3, 4, 6, 7}
    right_contact = phase in {0, 1, 2, 3, 6}
    if action not in {"walkLeft", "walkRight", "runLeft", "runRight"}:
        left_contact = right_contact = True
    return [
        {
            "id": "leftSupport",
            "point": {"x": round(pair[0], 6), "y": 537.0},
            "contact": left_contact,
        },
        {
            "id": "rightSupport",
            "point": {"x": round(pair[1], 6), "y": 537.0},
            "contact": right_contact,
        },
    ]


def action_spec(
    semantic: dict[str, Any],
    frames: list[Image.Image],
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": semantic["id"],
        "loop": semantic["loop"],
        "fps": semantic["fps"],
        "startPose": semantic["startPose"],
        "endPose": semantic["endPose"],
        "frameMetadata": [
            {
                "rootAnchor": {"x": 332.5, "y": 537.0},
                "supportAnchors": support_pair(semantic["id"], index, len(frames)),
            }
            for index in range(len(frames))
        ],
    }
    for name in ("holdStartMs", "holdEndMs"):
        if name in semantic:
            result[name] = semantic[name]
    if semantic["loop"]:
        result["loopStartFrame"] = 0
    return result


def write_action(
    output_root: Path,
    action: str,
    frames: Iterable[Image.Image],
    provenance: Iterable[dict[str, Any]],
) -> tuple[list[Image.Image], list[dict[str, Any]]]:
    directory = output_root / "frames" / action
    directory.mkdir(parents=True, exist_ok=False)
    frame_list = [frame.copy() for frame in frames]
    provenance_list = [dict(item) for item in provenance]
    if len(frame_list) != 24 or len(provenance_list) != 24:
        raise FoundationBuildError(f"{action}: expected exactly 24 frames")
    for index, (frame, record) in enumerate(zip(frame_list, provenance_list)):
        output = directory / f"{index:03d}.png"
        frame.save(output, format="PNG", optimize=True)
        with Image.open(output) as reopened:
            if reopened.mode != "RGBA" or reopened.info.get("icc_profile"):
                raise FoundationBuildError(f"{output}: canonical PNG encoding failed")
            if reopened.size != (665, 737):
                raise FoundationBuildError(f"{output}: authored canvas changed")
        record["action"] = action
        record["frame"] = index
        record["output"] = str(output)
        record["outputSHA256"] = sha256_file(output)
    return frame_list, provenance_list


def mirror_provenance(record: dict[str, Any], source_action: str) -> dict[str, Any]:
    result = dict(record)
    result["derivedBy"] = "horizontal-mirror"
    result["derivedFromAction"] = source_action
    result["pixelScaleChanged"] = False
    return result


def build(
    *,
    draft_root: Path,
    contract_path: Path,
    output_root: Path,
) -> dict[str, Any]:
    if output_root.exists():
        raise FoundationBuildError(f"output already exists: {output_root}")
    contract = load_json(contract_path)
    if (
        contract.get("schemaVersion") != "catatwork.foundation/v2"
        or contract.get("status") != "frozen"
        or tuple(contract["scope"]["actions"]) != EXPECTED_ACTIONS
        or contract["scope"]["frameCount"] != 216
    ):
        raise FoundationBuildError("foundation contract scope is not frozen")
    canvas = contract["authoredCanvas"]
    if (
        canvas["width"] != 665
        or canvas["height"] != 737
        or canvas["safeMargin"] != 16
        or contract["canonicalScale"]["pixelsPerBodyUnit"] != 220
    ):
        raise FoundationBuildError("foundation scale/canvas contract changed")
    component_policy = contract["componentPolicy"]
    if component_policy.get("exceptions") != []:
        raise FoundationBuildError("foundation component exceptions are forbidden")
    root = contract["rootSystem"]["anatomicalRoot"]
    centroid_proxy_offset_x = float(
        contract["rootSystem"]["alphaCentroidProxyOffsetX"]
    )

    loaded = {
        take: load_take(draft_root, take)
        for take_group in TAKES.values()
        for take in take_group
    }
    authored: dict[tuple[str, int], tuple[Image.Image, dict[str, Any]]] = {}
    for take, frames in loaded.items():
        for frame in frames:
            authored[(take, frame.index)] = author_canvas(
                frame,
                canvas=canvas,
                root=root,
                component_policy=component_policy,
                material_references=contract["materialReferences"],
                centroid_proxy_offset_x=centroid_proxy_offset_x,
            )

    output_root.mkdir(parents=True)
    build_records: dict[str, list[dict[str, Any]]] = {}
    action_images: dict[str, list[Image.Image]] = {}

    idle_cycle = [authored[("idle", index)] for index in range(8)]
    idle_order = list(range(4)) * 5 + [0, 1, 2, 0]
    idle_frames = [idle_cycle[index][0] for index in idle_order]
    idle_records = [idle_cycle[index][1] for index in idle_order]
    action_images["idle"], build_records["idle"] = write_action(
        output_root, "idle", idle_frames, idle_records
    )

    walk_cycle = [authored[("walkLeft-cycle", index)] for index in range(8)]
    walk_order = [7] + list(range(8)) * 2 + list(range(6)) + [7]
    walk_frames = [walk_cycle[index][0] for index in walk_order]
    walk_records = [walk_cycle[index][1] for index in walk_order]
    action_images["walkRight"], build_records["walkRight"] = write_action(
        output_root, "walkRight", walk_frames, walk_records
    )

    # Retain the four reviewed, semantically alternating gather/extend phases
    # and share the exact frozen standing endpoint with the walk/bridge family.
    run_cycle = [authored[("runLeft-cycle", index)] for index in (1, 3, 4, 7)]
    run_bridge = authored[("run-bridge-variants", 6)]
    run_middle_order = list(range(4)) * 5
    run_frames = [action_images["walkRight"][0], run_bridge[0]] + [
        run_cycle[index][0] for index in run_middle_order
    ] + [run_bridge[0], action_images["walkRight"][0]]
    run_records = [
        {
            **build_records["walkRight"][0],
            "derivedBy": "canonical-standing-endpoint-copy",
            "derivedFromAction": "walkRight",
            "pixelScaleChanged": False,
        },
        {
            **run_bridge[1],
            "foundationRole": "reviewed-run-entry-exit-bridge",
            "pixelScaleChanged": False,
        },
    ] + [run_cycle[index][1] for index in run_middle_order] + [
        {
            **run_bridge[1],
            "foundationRole": "reviewed-run-entry-exit-bridge",
            "pixelScaleChanged": False,
        },
        {
            **build_records["walkRight"][0],
            "derivedBy": "canonical-standing-endpoint-copy",
            "derivedFromAction": "walkRight",
            "pixelScaleChanged": False,
        }
    ]
    action_images["runRight"], build_records["runRight"] = write_action(
        output_root, "runRight", run_frames, run_records
    )

    for action, source_action in (
        ("walkLeft", "walkRight"),
        ("runLeft", "runRight"),
    ):
        images = [
            frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            for frame in action_images[source_action]
        ]
        records = [
            mirror_provenance(record, source_action)
            for record in build_records[source_action]
        ]
        action_images[action], build_records[action] = write_action(
            output_root, action, images, records
        )

    sit_keys = [
        (action_images["idle"][0], build_records["idle"][0]),
        authored[("lieDown-take3", 0)],
        authored[("lieDown-take2", 1)],
        authored[("sitToStand-key", 0)],
        authored[("sitToStand-key", 1)],
        authored[("lieDown-take5", 0)],
        authored[("sitToStand-key", 4)],
        authored[("sitToStand-key", 5)],
        authored[("sitToStand-take2", 6)],
        authored[("sitToStand-take2", 5)],
        (action_images["walkRight"][0], build_records["walkRight"][0]),
    ]
    sit_selected = [sit_keys[0]] * 3 + [
        item
        for key in sit_keys[1:-1]
        for item in (key, key)
    ] + [sit_keys[-1]] * 3
    sit_records = []
    for order, (_, record) in enumerate(sit_selected):
        role = "reviewed-inbetween"
        if order < 3:
            role = "canonical-seated-endpoint"
        elif order >= 21:
            role = "canonical-standing-endpoint"
        sit_records.append(
            {
                **record,
                "foundationRole": role,
                "selectionOrder": order,
                "pixelScaleChanged": False,
            }
        )
    action_images["sitToStand"], build_records["sitToStand"] = write_action(
        output_root,
        "sitToStand",
        [item[0] for item in sit_selected],
        sit_records,
    )

    lie_order = [
        ("idle", 0),
        ("idle", 0),
        ("idle", 0),
        ("lieDown-take3", 0),
        ("lieDown-take2", 1),
        ("lieDown-take1", 0),
        ("lieDown-take3", 1),
        ("lieDown-take1", 1),
        ("lieDown-take5", 0),
        ("lieDown-take4", 0),
        ("lieDown-take5", 1),
        ("lieDown-take4", 1),
        ("lieDown-take5", 2),
        ("lieDown-take4", 2),
        ("lieDown-take7", 7),
        ("lieDown-take2", 4),
        ("lieDown-take4", 3),
        ("lieDown-take4", 4),
        ("lieDown-take5", 6),
        ("lieDown-take4", 5),
        ("lieDown-take4", 6),
        ("lieDown-take4", 7),
        ("lieDown-take4", 7),
        ("lieDown-take4", 7),
    ]
    lie_selected = [
        (
            (action_images["idle"][0], build_records["idle"][0])
            if take == "idle"
            else authored[(take, index)]
        )
        for take, index in lie_order
    ]
    lie_records = []
    for order, (_, record) in enumerate(lie_selected):
        role = "reviewed-inbetween"
        if order < 3:
            role = "canonical-seated-endpoint"
        elif order >= 21:
            role = "canonical-lying-endpoint"
        lie_records.append(
            {
                **record,
                "foundationRole": role,
                "selectionOrder": order,
                "pixelScaleChanged": False,
            }
        )
    action_images["lieDown"], build_records["lieDown"] = write_action(
        output_root,
        "lieDown",
        [item[0] for item in lie_selected],
        lie_records,
    )

    for action, source_action in (
        ("standToSit", "sitToStand"),
        ("getUp", "lieDown"),
    ):
        images = [frame.copy() for frame in reversed(action_images[source_action])]
        records = [
            {
                **record,
                "derivedBy": "exact-frame-order-reversal",
                "derivedFromAction": source_action,
                "pixelScaleChanged": False,
            }
            for record in reversed(build_records[source_action])
        ]
        action_images[action], build_records[action] = write_action(
            output_root, action, images, records
        )

    semantics = {item["id"]: item for item in contract["actionSemantics"]}
    sheet_views = {item["id"]: item for item in contract["identitySheet"]["views"]}
    identity_rig = {
        "views": [
            identity_view(
                identifier="front",
                sheet_view=sheet_views["front"],
                reference_action="idle",
                reference_frame=0,
                reference_image=action_images["idle"][0],
                canvas=canvas,
            ),
            identity_view(
                identifier="leftProfile",
                sheet_view=sheet_views["leftProfile"],
                reference_action="walkLeft",
                reference_frame=0,
                reference_image=action_images["walkLeft"][0],
                canvas=canvas,
            ),
            identity_view(
                identifier="rightProfile",
                sheet_view=sheet_views["rightProfile"],
                reference_action="walkRight",
                reference_frame=0,
                reference_image=action_images["walkRight"][0],
                canvas=canvas,
            ),
            identity_view(
                identifier="lyingLeft",
                sheet_view=sheet_views["leftProfile"],
                reference_action="lieDown",
                reference_frame=23,
                reference_image=action_images["lieDown"][23],
                canvas=canvas,
            ),
        ]
    }
    spec = {
        "contractVersion": 2,
        "petId": "cat-at-work",
        "displayName": "猫上班了",
        "author": "猫上班了",
        "description": "B4 foundation production slice; partial non-release package.",
        "minimumAppVersion": "1.0.0",
        "assetVersion": "2026.07.27.foundation.1",
        "pixelsPerBodyUnit": 220,
        "minimumFramesPerAnimation": 24,
        "authoredCanvas": {
            "width": canvas["width"],
            "height": canvas["height"],
            "safeMargin": canvas["safeMargin"],
        },
        "colorSpace": canvas["colorSpace"],
        "componentPolicy": component_policy,
        "identityRig": identity_rig,
        "actions": [
            action_spec(semantics[action], action_images[action])
            for action in EXPECTED_ACTIONS
        ],
    }
    spec_path = output_root / "animation-spec.json"
    spec_path.write_bytes(canonical_json(spec))

    report = {
        "schemaVersion": SCHEMA,
        "foundationContract": {
            "path": str(contract_path),
            "sha256": sha256_file(contract_path),
        },
        "sourceSheetSize": list(EXPECTED_SOURCE_SIZE),
        "pixelOperations": [
            "chroma-key",
            "connected-pose-extraction",
            "transparent-padding-crop",
            "integer-translation-to-authored-canvas",
            "fixed-source-effect-detail-preserving-material-pull",
            "exact-order-reversal",
            "horizontal-pixel-mirror",
        ],
        "resizingOrResampling": False,
        "actions": build_records,
        "summary": {
            "actionCount": len(build_records),
            "frameCount": sum(len(items) for items in build_records.values()),
            "canvas": [canvas["width"], canvas["height"]],
            "pixelsPerBodyUnit": contract["canonicalScale"]["pixelsPerBodyUnit"],
            "componentExceptions": len(component_policy["exceptions"]),
        },
        "animationSpecSHA256": sha256_file(spec_path),
    }
    report_path = output_root / "foundation-build-report.json"
    report_path.write_bytes(canonical_json(report))
    return {
        "output": str(output_root),
        "spec": str(spec_path),
        "report": str(report_path),
        "frameCount": report["summary"]["frameCount"],
    }


def install(candidate_root: Path, assets_root: Path) -> dict[str, Any]:
    report = load_json(candidate_root / "foundation-build-report.json")
    if (
        report.get("schemaVersion") != SCHEMA
        or report.get("summary", {}).get("frameCount") != 216
        or report.get("resizingOrResampling") is not False
    ):
        raise FoundationBuildError("candidate report is not installable")
    spec = load_json(candidate_root / "animation-spec.json")
    action_ids = tuple(item["id"] for item in spec.get("actions", []))
    if action_ids != EXPECTED_ACTIONS:
        raise FoundationBuildError("candidate action scope changed")
    targets: list[Path] = []
    for action in EXPECTED_ACTIONS:
        source_dir = candidate_root / "frames" / action
        paths = sorted(source_dir.glob("*.png"))
        if len(paths) != 24:
            raise FoundationBuildError(f"{action}: candidate is incomplete")
        target_dir = assets_root / "frames" / action
        if not target_dir.is_dir() or len(list(target_dir.glob("*.png"))) != 24:
            raise FoundationBuildError(f"{action}: production target is not the expected 24 frames")
        for source in paths:
            target = target_dir / source.name
            shutil.copyfile(source, target)
            targets.append(target)
    production_spec = load_json(assets_root / "animation-spec.json")
    production_actions = tuple(
        item["id"] for item in production_spec.get("actions", [])
    )
    missing = sorted(set(EXPECTED_ACTIONS) - set(production_actions))
    if missing:
        raise FoundationBuildError(
            f"production authoring spec is missing scoped actions: {missing}"
        )
    return {
        "installedFrames": len(targets),
        "actions": list(EXPECTED_ACTIONS),
        "candidateSpecSHA256": sha256_file(
            candidate_root / "animation-spec.json"
        ),
        "productionSpecModified": False,
        "productionSpec": str(assets_root / "animation-spec.json"),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    build_parser = subparsers.add_parser("build")
    build_parser.add_argument("--draft-root", required=True, type=Path)
    build_parser.add_argument("--contract", required=True, type=Path)
    build_parser.add_argument("--output-root", required=True, type=Path)
    install_parser = subparsers.add_parser("install")
    install_parser.add_argument("--candidate-root", required=True, type=Path)
    install_parser.add_argument("--assets-root", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "build":
        result = build(
            draft_root=args.draft_root,
            contract_path=args.contract,
            output_root=args.output_root,
        )
    else:
        result = install(args.candidate_root, args.assets_root)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
