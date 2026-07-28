#!/usr/bin/env python3
"""Validate the accepted source-effect to authored foundation color mapping."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

from PIL import Image

from assemble_foundation_assets import material_label, normalize_material_colors
from validate_visual_qa import (
    canonical_bytes,
    ciede2000,
    material_labs,
    sha256_file,
    srgb_to_lab,
)


REPORT_SCHEMA = "catatwork.foundation-color-oracle/v1"
MATERIALS = ("light", "warm", "dark")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def material_detail_metrics(
    source: Image.Image,
    authored: Image.Image,
    *,
    material_references: dict[str, Any],
) -> dict[str, dict[str, float | int | None]]:
    if source.size != authored.size:
        raise ValueError("detail metrics require equal source/authored size")
    width, height = source.size
    source_pixels = list(source.getdata())
    authored_pixels = list(authored.getdata())
    normalization = material_references["normalization"]
    lightness_cache: dict[tuple[int, int, int], float] = {}
    labels = [
        material_label(
            pixel,
            normalization=normalization,
            lightness_cache=lightness_cache,
        )
        for pixel in source_pixels
    ]
    source_lightness: dict[tuple[int, int, int], float] = {}
    authored_lightness: dict[tuple[int, int, int], float] = {}

    def lightness(
        pixel: tuple[int, int, int, int],
        cache: dict[tuple[int, int, int], float],
    ) -> float:
        rgb = pixel[:3]
        value = cache.get(rgb)
        if value is None:
            value = srgb_to_lab(*rgb)[0]
            cache[rgb] = value
        return value

    gradients = {
        material: {"source": [], "authored": []}
        for material in MATERIALS
    }
    for y in range(height):
        for x in range(width):
            offset = y * width + x
            material = labels[offset]
            if material is None:
                continue
            for neighbor in (
                offset + 1 if x + 1 < width else -1,
                offset + width if y + 1 < height else -1,
            ):
                if neighbor < 0 or labels[neighbor] != material:
                    continue
                gradients[material]["source"].append(
                    abs(
                        lightness(source_pixels[offset], source_lightness)
                        - lightness(source_pixels[neighbor], source_lightness)
                    )
                )
                gradients[material]["authored"].append(
                    abs(
                        lightness(authored_pixels[offset], authored_lightness)
                        - lightness(authored_pixels[neighbor], authored_lightness)
                    )
                )

    result: dict[str, dict[str, float | int | None]] = {}
    for material, values in gradients.items():
        source_values = values["source"]
        authored_values = values["authored"]
        source_rms = (
            math.sqrt(
                sum(value * value for value in source_values)
                / len(source_values)
            )
            if source_values
            else None
        )
        authored_rms = (
            math.sqrt(
                sum(value * value for value in authored_values)
                / len(authored_values)
            )
            if authored_values
            else None
        )
        ratio = (
            authored_rms / source_rms
            if source_rms is not None
            and authored_rms is not None
            and source_rms > 0
            else None
        )
        result[material] = {
            "pairCount": len(source_values),
            "sourceGradientRMS": source_rms,
            "authoredGradientRMS": authored_rms,
            "authoredRatio": ratio,
        }
    return result


def validate_color_oracle(
    *,
    source_effect_sheet: Path,
    source_effect_frame: Path,
    foundation_path: Path,
) -> dict[str, Any]:
    foundation = load_json(foundation_path)
    references = foundation["materialReferences"]
    oracle = references["sourceEffectOracle"]
    sheet_sha = sha256_file(source_effect_sheet)
    frame_sha = sha256_file(source_effect_frame)

    with Image.open(source_effect_frame) as opened:
        source_mode = opened.mode
        source_icc = bool(opened.info.get("icc_profile"))
        source = opened.copy() if opened.mode == "RGBA" else opened.convert("RGBA")

    authored = normalize_material_colors(
        source,
        material_references=references,
    )
    source_labs = material_labs(source)
    authored_labs = material_labs(authored)
    recorded_labs = {
        material: tuple(float(value) for value in oracle["materialLabs"][material])
        for material in MATERIALS
    }
    lab_tolerance = float(oracle["materialLabTolerance"])
    maximum_delta = float(oracle["maximumAuthoredDeltaE00"])
    alpha_minimum = int(oracle["visibleAlphaMinimum"])
    visible_source = [
        pixel
        for pixel in source.getdata()
        if pixel[3] >= alpha_minimum
    ]
    visible_pairs = [
        (before, after)
        for before, after in zip(source.getdata(), authored.getdata())
        if before[3] >= alpha_minimum
    ]
    material_deltas = {
        material: (
            ciede2000(source_labs[material], authored_labs[material])
            if source_labs[material] is not None
            and authored_labs[material] is not None
            else None
        )
        for material in MATERIALS
    }
    source_lab_errors = {
        material: (
            max(
                abs(actual - expected)
                for actual, expected in zip(source_labs[material], recorded_labs[material])
            )
            if source_labs[material] is not None
            else None
        )
        for material in MATERIALS
    }
    detail_contract = oracle["detailRetention"]
    detail_metrics = material_detail_metrics(
        source,
        authored,
        material_references=references,
    )
    detail_tolerance = float(detail_contract["sourceMetricTolerance"])
    detail_source_errors = {
        material: (
            abs(
                float(detail_metrics[material]["sourceGradientRMS"])
                - float(detail_contract["sourceGradientRMS"][material])
            )
            if detail_metrics[material]["sourceGradientRMS"] is not None
            else None
        )
        for material in MATERIALS
    }
    minimum_detail_ratio = float(detail_contract["minimumAuthoredRatio"])
    maximum_detail_ratio = float(detail_contract["maximumAuthoredRatio"])

    checks = [
        {
            "id": "contract/schema",
            "passed": foundation.get("schemaVersion") == "catatwork.foundation/v2",
        },
        {
            "id": "source/sheet-sha256",
            "passed": sheet_sha == oracle["sourceSheetSHA256"],
            "actual": sheet_sha,
            "expected": oracle["sourceSheetSHA256"],
        },
        {
            "id": "source/frame-sha256",
            "passed": frame_sha == oracle["sourceFrameSHA256"],
            "actual": frame_sha,
            "expected": oracle["sourceFrameSHA256"],
        },
        {
            "id": "source/encoding",
            "passed": source_mode == "RGBA" and not source_icc,
            "mode": source_mode,
            "embeddedICC": source_icc,
        },
        {
            "id": "source/size",
            "passed": list(source.size) == oracle["sourceFrameSize"],
            "actual": list(source.size),
            "expected": oracle["sourceFrameSize"],
        },
        {
            "id": "source/visible-pixel-count",
            "passed": len(visible_source) == int(oracle["visiblePixelCount"]),
            "actual": len(visible_source),
            "expected": int(oracle["visiblePixelCount"]),
            "alphaMinimum": alpha_minimum,
        },
        {
            "id": "source/material-labs",
            "passed": all(
                error is not None and error <= lab_tolerance
                for error in source_lab_errors.values()
            ),
            "maximumComponentErrors": {
                material: round(error, 9) if error is not None else None
                for material, error in source_lab_errors.items()
            },
            "tolerance": lab_tolerance,
        },
        {
            "id": "source/detail-metrics",
            "passed": all(
                detail_metrics[material]["pairCount"]
                == int(detail_contract["sourcePairCounts"][material])
                and detail_source_errors[material] is not None
                and detail_source_errors[material] <= detail_tolerance
                for material in MATERIALS
            ),
            "metric": detail_contract["metric"],
            "measurements": {
                material: {
                    "pairCount": detail_metrics[material]["pairCount"],
                    "gradientRMS": round(
                        float(detail_metrics[material]["sourceGradientRMS"]),
                        6,
                    ),
                    "maximumError": round(
                        float(detail_source_errors[material]),
                        9,
                    ),
                }
                for material in MATERIALS
                if detail_metrics[material]["sourceGradientRMS"] is not None
                and detail_source_errors[material] is not None
            },
            "tolerance": detail_tolerance,
        },
        {
            "id": "authored/size-identity",
            "passed": (
                not oracle["requireSizeIdentity"]
                or authored.size == source.size
            ),
            "source": list(source.size),
            "authored": list(authored.size),
        },
        {
            "id": "authored/alpha-identity",
            "passed": (
                not oracle["requireAlphaIdentity"]
                or authored.getchannel("A").tobytes()
                == source.getchannel("A").tobytes()
            ),
        },
        {
            "id": "authored/material-delta",
            "passed": all(
                delta is not None and delta <= maximum_delta
                for delta in material_deltas.values()
            ),
            "maximumDeltaE00": maximum_delta,
            "measurements": {
                material: round(delta, 6) if delta is not None else None
                for material, delta in material_deltas.items()
            },
        },
        {
            "id": "authored/detail-retention",
            "passed": all(
                detail_metrics[material]["authoredRatio"] is not None
                and minimum_detail_ratio
                <= float(detail_metrics[material]["authoredRatio"])
                <= maximum_detail_ratio
                for material in MATERIALS
            ),
            "metric": detail_contract["metric"],
            "minimumRatio": minimum_detail_ratio,
            "maximumRatio": maximum_detail_ratio,
            "measurements": {
                material: {
                    "sourceGradientRMS": round(
                        float(detail_metrics[material]["sourceGradientRMS"]),
                        6,
                    ),
                    "authoredGradientRMS": round(
                        float(detail_metrics[material]["authoredGradientRMS"]),
                        6,
                    ),
                    "ratio": round(
                        float(detail_metrics[material]["authoredRatio"]),
                        6,
                    ),
                }
                for material in MATERIALS
                if detail_metrics[material]["sourceGradientRMS"] is not None
                and detail_metrics[material]["authoredGradientRMS"] is not None
                and detail_metrics[material]["authoredRatio"] is not None
            },
        },
    ]
    failures = [check["id"] for check in checks if not check["passed"]]
    return {
        "schemaVersion": REPORT_SCHEMA,
        "oracle": {
            "referenceId": oracle["referenceId"],
            "sourceSheetSHA256": sheet_sha,
            "sourceFrameSHA256": frame_sha,
        },
        "normalization": references["normalization"],
        "sourceMaterials": {
            material: (
                [round(component, 6) for component in source_labs[material]]
                if source_labs[material] is not None
                else None
            )
            for material in MATERIALS
        },
        "authoredMaterials": {
            material: (
                [round(component, 6) for component in authored_labs[material]]
                if authored_labs[material] is not None
                else None
            )
            for material in MATERIALS
        },
        "detailRetention": {
            material: {
                key: (
                    round(float(value), 6)
                    if isinstance(value, float)
                    else value
                )
                for key, value in detail_metrics[material].items()
            }
            for material in MATERIALS
        },
        "changedVisiblePixels": sum(
            before != after
            for before, after in visible_pairs
        ),
        "visiblePixelCount": len(visible_pairs),
        "checks": checks,
        "summary": {
            "decision": "pass" if not failures else "fail",
            "checkCount": len(checks),
            "failureCount": len(failures),
            "failures": failures,
        },
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-effect-sheet", required=True, type=Path)
    parser.add_argument("--source-effect-frame", required=True, type=Path)
    parser.add_argument("--foundation-contract", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = validate_color_oracle(
        source_effect_sheet=args.source_effect_sheet,
        source_effect_frame=args.source_effect_frame,
        foundation_path=args.foundation_contract,
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_bytes(canonical_bytes(report, pretty=True))
    print(
        json.dumps(
            {
                "decision": report["summary"]["decision"],
                "report": str(args.report),
                "changedVisiblePixels": report["changedVisiblePixels"],
                "visiblePixelCount": report["visiblePixelCount"],
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    if report["summary"]["decision"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
