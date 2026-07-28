#!/usr/bin/env python3
"""Validate the partial B4 foundation package against frozen B2/B3 gates."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import statistics
from pathlib import Path
from typing import Any

from PIL import Image

from validate_visual_qa import (
    canonical_bytes,
    ciede2000,
    evaluate_observations,
    image_digest,
    scan_static,
    sha256_file,
    srgb_to_lab,
    tree_digest,
)


REPORT_SCHEMA = "catatwork.foundation-validation/v1"
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


class FoundationValidationError(ValueError):
    """The candidate cannot be evaluated against the frozen scope."""


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def projected_b2_contract(
    contract: dict[str, Any],
    *,
    package_digest: str,
) -> dict[str, Any]:
    projected = copy.deepcopy(contract)
    projected["baseline"]["packageDigest"] = package_digest
    projected["baseline"]["expectedFindingIds"] = []
    scope = set(EXPECTED_ACTIONS)
    action_contracts = []
    for group in projected["actionContracts"]:
        actions = [action for action in group["actions"] if action in scope]
        if actions:
            action_contracts.append({**group, "actions": actions})
    projected["actionContracts"] = action_contracts
    return projected


def frame_paths(candidate_root: Path, action: str) -> list[Path]:
    paths = sorted((candidate_root / "frames" / action).glob("*.png"))
    expected = [f"{index:03d}.png" for index in range(24)]
    if [path.name for path in paths] != expected:
        raise FoundationValidationError(f"{action}: expected frames 000.png through 023.png")
    return paths


def rgba_digest(path: Path) -> str:
    with Image.open(path) as opened:
        if opened.mode != "RGBA":
            raise FoundationValidationError(f"{path}: expected RGBA")
        return image_digest(opened.convert("RGBA"))


def alpha_centroid(image: Image.Image, *, threshold: int = 12) -> tuple[float, float]:
    alpha = list(image.getchannel("A").getdata())
    occupied = [offset for offset, value in enumerate(alpha) if value >= threshold]
    if not occupied:
        raise FoundationValidationError("cannot measure an empty frame")
    return (
        sum(offset % image.width for offset in occupied) / len(occupied),
        sum(offset // image.width for offset in occupied) / len(occupied),
    )


def exact_endpoint_checks(candidate_root: Path) -> list[dict[str, Any]]:
    groups = (
        (
            "seated",
            (
                ("idle", 0),
                ("sitToStand", 0),
                ("standToSit", 23),
                ("lieDown", 0),
                ("getUp", 23),
            ),
        ),
        (
            "standing-bridge",
            (
                ("sitToStand", 23),
                ("standToSit", 0),
            ),
        ),
        (
            "lying",
            (
                ("lieDown", 23),
                ("getUp", 0),
            ),
        ),
    )
    checks = []
    for pose, endpoints in groups:
        digests = {
            f"{action}:{index + 1}": rgba_digest(
                candidate_root / "frames" / action / f"{index:03d}.png"
            )
            for action, index in endpoints
        }
        checks.append(
            {
                "id": f"endpoint/{pose}",
                "passed": len(set(digests.values())) == 1,
                "digests": digests,
            }
        )
    return checks


def mirror_checks(candidate_root: Path) -> list[dict[str, Any]]:
    checks = []
    for left, right in (("walkLeft", "walkRight"), ("runLeft", "runRight")):
        mismatches = []
        for index in range(24):
            left_path = candidate_root / "frames" / left / f"{index:03d}.png"
            right_path = candidate_root / "frames" / right / f"{index:03d}.png"
            with Image.open(left_path) as left_opened, Image.open(right_path) as right_opened:
                mirrored = left_opened.convert("RGBA").transpose(
                    Image.Transpose.FLIP_LEFT_RIGHT
                )
                if image_digest(mirrored) != image_digest(right_opened.convert("RGBA")):
                    mismatches.append(index + 1)
        checks.append(
            {
                "id": f"mirror/{left}-{right}",
                "passed": not mismatches,
                "mismatchedFrames": mismatches,
            }
        )
    return checks


def direction_facing_check(
    candidate_root: Path,
    *,
    foundation: dict[str, Any],
) -> dict[str, Any]:
    policy = foundation["directionFacingPolicy"]
    split_x = float(policy["splitX"])
    clearance = float(policy["minimumSideClearance"])
    violations = []
    measurements: dict[str, list[float]] = {}
    for action, direction in policy["actions"].items():
        values = []
        for index, path in enumerate(frame_paths(candidate_root, action)):
            with Image.open(path) as opened:
                image = opened.convert("RGBA")
            bbox = image.getchannel("A").getbbox()
            if bbox is None:
                violations.append(
                    {"action": action, "frame": index + 1, "reason": "empty"}
                )
                continue
            upper_height = max(
                1,
                round(
                    (bbox[3] - bbox[1])
                    * float(policy["upperBodyFraction"])
                ),
            )
            upper = image.crop(
                (bbox[0], bbox[1], bbox[2], bbox[1] + upper_height)
            )
            dark_x = [
                bbox[0] + offset % upper.width
                for offset, (red, green, blue, alpha) in enumerate(
                    upper.getdata()
                )
                if alpha >= int(policy["alphaMinimum"])
                and max(red, green, blue) <= int(policy["darkChannelMaximum"])
            ]
            if not dark_x:
                violations.append(
                    {
                        "action": action,
                        "frame": index + 1,
                        "reason": "no-upper-dark-support",
                    }
                )
                continue
            centroid_x = sum(dark_x) / len(dark_x)
            values.append(round(centroid_x, 6))
            correct_side = (
                centroid_x <= split_x - clearance
                if direction == "left"
                else centroid_x >= split_x + clearance
            )
            if not correct_side:
                violations.append(
                    {
                        "action": action,
                        "frame": index + 1,
                        "direction": direction,
                        "upperDarkCentroidX": round(centroid_x, 6),
                    }
                )
        measurements[action] = values
    return {
        "id": "semantics/locomotion-facing-direction",
        "passed": not violations,
        "policy": policy,
        "measurements": measurements,
        "violations": violations,
    }


def canonical_material_check(
    candidate_root: Path,
    *,
    foundation: dict[str, Any],
) -> dict[str, Any]:
    references = foundation["materialReferences"]
    normalization = references["normalization"]
    maximum = float(references["sampling"]["canonicalMaximumDeltaE00"])
    reference_labs = {
        "light": srgb_to_lab(*references["lightCoat"]["srgbMedian"]),
        "warm": srgb_to_lab(*references["warmCoat"]["srgbMedian"]),
        "dark": srgb_to_lab(*references["darkMask"]["srgbMedian"]),
    }
    violations = []
    measurements = []
    for action in EXPECTED_ACTIONS:
        for index, path in enumerate(frame_paths(candidate_root, action)):
            with Image.open(path) as opened:
                sample = opened.convert("RGBA")
            sample.thumbnail((128, 128), Image.Resampling.NEAREST)
            groups: dict[str, list[tuple[float, float, float]]] = {
                "light": [],
                "warm": [],
                "dark": [],
            }
            for red, green, blue, alpha in sample.getdata():
                if alpha < int(references["sampling"]["alphaMinimum"]):
                    continue
                lab = srgb_to_lab(red, green, blue)
                if lab[0] <= float(normalization["darkMaximumLStar"]):
                    groups["dark"].append(lab)
                elif lab[0] >= float(normalization["lightMinimumLStar"]):
                    groups["light"].append(lab)
                elif red >= green + 8 and green >= blue:
                    groups["warm"].append(lab)
            materials = {
                material: (
                    tuple(
                        statistics.median(component)
                        for component in zip(*values)
                    )
                    if len(values) >= 8
                    else None
                )
                for material, values in groups.items()
            }
            for material, reference_lab in reference_labs.items():
                actual = materials[material]
                if actual is None:
                    violations.append(
                        {
                            "action": action,
                            "frame": index + 1,
                            "material": material,
                            "reason": "insufficient-samples",
                        }
                    )
                    continue
                delta = ciede2000(actual, reference_lab)
                measurements.append(
                    {
                        "action": action,
                        "frame": index + 1,
                        "material": material,
                        "deltaE00": round(delta, 6),
                    }
                )
                if delta > maximum:
                    violations.append(measurements[-1])
    return {
        "id": "material/canonical-reference-delta",
        "passed": not violations,
        "maximumDeltaE00": maximum,
        "measurements": measurements,
        "violations": violations,
    }


def source_checks(
    candidate_root: Path,
    *,
    foundation: dict[str, Any],
    build_report: dict[str, Any],
    spec: dict[str, Any],
) -> list[dict[str, Any]]:
    canvas = foundation["authoredCanvas"]
    component_policy = foundation["componentPolicy"]
    checks: list[dict[str, Any]] = []
    oracle = foundation["materialReferences"].get("sourceEffectOracle")
    detail = oracle.get("detailRetention") if isinstance(oracle, dict) else None
    checks.append(
        {
            "id": "material/source-effect-oracle-contract",
            "passed": (
                foundation.get("schemaVersion") == "catatwork.foundation/v2"
                and isinstance(oracle, dict)
                and oracle.get("referenceId") == "interaction-waiting-pose-0"
                and oracle.get("maximumAuthoredDeltaE00") == 3
                and oracle.get("requireSizeIdentity") is True
                and oracle.get("requireAlphaIdentity") is True
                and isinstance(detail, dict)
                and detail.get("metric")
                == "same-material-right-down-lstar-gradient-rms-ratio"
                and detail.get("minimumAuthoredRatio") == 0.98
                and detail.get("maximumAuthoredRatio") == 1.05
            ),
            "schemaVersion": foundation.get("schemaVersion"),
            "oracleReferenceId": (
                oracle.get("referenceId") if isinstance(oracle, dict) else None
            ),
        }
    )
    action_ids = tuple(action["id"] for action in spec.get("actions", []))
    checks.append(
        {
            "id": "scope/actions",
            "passed": action_ids == EXPECTED_ACTIONS,
            "actual": list(action_ids),
            "expected": list(EXPECTED_ACTIONS),
        }
    )
    forbidden = []
    for action in spec.get("actions", []):
        for field in ("authoringScale", "bodyScale", "pivotMode", "renderOffsets"):
            if field in action:
                forbidden.append(f"{action.get('id')}:{field}")
    checks.append(
        {
            "id": "scale/no-action-or-frame-resize",
            "passed": (
                not forbidden
                and build_report.get("resizingOrResampling") is False
                and all(
                    record.get("pixelScaleChanged") is False
                    for records in build_report.get("actions", {}).values()
                    for record in records
                )
            ),
            "forbiddenFields": forbidden,
            "reportedResizingOrResampling": build_report.get(
                "resizingOrResampling"
            ),
        }
    )
    bad_frames = []
    support_bottoms: dict[str, list[int]] = {}
    for action in EXPECTED_ACTIONS:
        paths = frame_paths(candidate_root, action)
        bottoms = []
        for index, path in enumerate(paths):
            with Image.open(path) as opened:
                mode = opened.mode
                size = opened.size
                icc = bool(opened.info.get("icc_profile"))
                image = opened.convert("RGBA")
            bbox = image.getchannel("A").getbbox()
            bottom = bbox[3] if bbox else None
            bottoms.append(bottom)
            if (
                mode != "RGBA"
                or size != (canvas["width"], canvas["height"])
                or icc
                or bbox is None
                or min(
                    bbox[0],
                    bbox[1],
                    canvas["width"] - bbox[2],
                    canvas["height"] - bbox[3],
                )
                < canvas["safeMargin"]
            ):
                bad_frames.append(
                    {
                        "action": action,
                        "frame": index + 1,
                        "mode": mode,
                        "size": list(size),
                        "icc": icc,
                        "bbox": list(bbox) if bbox else None,
                    }
                )
        support_bottoms[action] = bottoms
    checks.append(
        {
            "id": "source/fixed-canvas-color-margin",
            "passed": not bad_frames,
            "violations": bad_frames,
        }
    )
    checks.append(
        {
            "id": "root-support/authored-line",
            "passed": all(
                bottom == foundation["rootSystem"]["supportLineY"]
                for bottoms in support_bottoms.values()
                for bottom in bottoms
            ),
            "supportBottoms": support_bottoms,
            "expected": foundation["rootSystem"]["supportLineY"],
        }
    )
    proxy_violations = []
    root_x = float(foundation["rootSystem"]["anatomicalRoot"]["x"])
    proxy_offset = float(
        foundation["rootSystem"]["alphaCentroidProxyOffsetX"]
    )
    for action in EXPECTED_ACTIONS:
        expected_x = root_x + proxy_offset
        if action in {"walkLeft", "runLeft"}:
            expected_x = canvas["width"] - 1 - expected_x
        for index, path in enumerate(frame_paths(candidate_root, action)):
            with Image.open(path) as opened:
                centroid_x, _ = alpha_centroid(opened.convert("RGBA"))
            if abs(centroid_x - expected_x) > 0.51:
                proxy_violations.append(
                    {
                        "action": action,
                        "frame": index + 1,
                        "actual": round(centroid_x, 6),
                        "expected": expected_x,
                    }
                )
    checks.append(
        {
            "id": "root-support/centroid-proxy-track",
            "passed": not proxy_violations,
            "violations": proxy_violations,
            "frontOrRightExpectedX": root_x + proxy_offset,
            "leftExpectedX": canvas["width"] - 1 - (root_x + proxy_offset),
            "tolerancePixels": 0.51,
        }
    )
    expected_normalization = {
        "method": foundation["materialReferences"]["normalization"]["method"],
        "sourceWeight": foundation["materialReferences"]["normalization"][
            "sourceWeight"
        ],
        "canonicalWeight": foundation["materialReferences"]["normalization"][
            "canonicalWeight"
        ],
        "detailNeighborhoodRadius": foundation["materialReferences"][
            "normalization"
        ]["detailNeighborhoodRadius"],
        "detailWeightNumerator": foundation["materialReferences"][
            "normalization"
        ]["detailWeightNumerator"],
        "detailWeightDenominator": foundation["materialReferences"][
            "normalization"
        ]["detailWeightDenominator"],
        "classificationAlphaMinimum": foundation["materialReferences"][
            "normalization"
        ]["classificationAlphaMinimum"],
        "perActionOrFrameTuning": False,
    }
    normalization_violations = [
        {
            "action": action,
            "frame": record.get("frame"),
            "actual": record.get("materialColorNormalization"),
        }
        for action, records in build_report.get("actions", {}).items()
        for record in records
        if record.get("materialColorNormalization") != expected_normalization
    ]
    checks.append(
        {
            "id": "material/fixed-detail-preserving-normalization",
            "passed": not normalization_violations,
            "expected": expected_normalization,
            "violations": normalization_violations,
        }
    )
    checks.append(
        canonical_material_check(
            candidate_root,
            foundation=foundation,
        )
    )
    checks.extend(exact_endpoint_checks(candidate_root))
    checks.extend(mirror_checks(candidate_root))
    checks.append(
        direction_facing_check(
            candidate_root,
            foundation=foundation,
        )
    )
    checks.append(
        {
            "id": "components/no-exceptions",
            "passed": (
                component_policy.get("exceptions") == []
                and spec.get("componentPolicy", {}).get("exceptions") == []
            ),
            "foundationExceptions": component_policy.get("exceptions"),
            "specExceptions": spec.get("componentPolicy", {}).get("exceptions"),
        }
    )
    return checks


def validate(
    *,
    candidate_root: Path,
    package_manifest: Path,
    foundation_path: Path,
    b2_contract_path: Path,
) -> dict[str, Any]:
    foundation = load_json(foundation_path)
    spec = load_json(candidate_root / "animation-spec.json")
    build_report = load_json(candidate_root / "foundation-build-report.json")
    manifest = load_json(package_manifest)
    package_root = package_manifest.parent
    package_digest = tree_digest(package_root)
    projected_contract = projected_b2_contract(
        load_json(b2_contract_path),
        package_digest=package_digest,
    )
    observations = scan_static(
        manifest=manifest,
        package_root=package_root,
        source_root=candidate_root,
        contract=projected_contract,
    )
    b2_report = evaluate_observations(
        mode="release",
        observations=observations,
        expected_failure_ids=[],
        waivers=[],
        package={
            "id": manifest.get("id"),
            "assetVersion": manifest.get("assetVersion"),
            "packageDigest": package_digest,
            "actionCount": len(manifest.get("animations", [])),
            "frameCount": sum(
                len(item.get("frames", []))
                for item in manifest.get("animations", [])
            ),
            "scope": list(EXPECTED_ACTIONS),
        },
        input_digests={
            "manifest": sha256_file(package_manifest),
            "package": package_digest,
            "source": tree_digest(candidate_root),
            "acceptedB2Contract": sha256_file(b2_contract_path),
            "projectedB2Contract": sha256_bytes(
                canonical_bytes(projected_contract)
            ),
            "foundationContract": sha256_file(foundation_path),
            "foundationBuildReport": sha256_file(
                candidate_root / "foundation-build-report.json"
            ),
        },
    )
    checks = source_checks(
        candidate_root,
        foundation=foundation,
        build_report=build_report,
        spec=spec,
    )
    failures = [check["id"] for check in checks if not check["passed"]]
    decision = b2_report["decision"] == "pass" and not failures
    return {
        "schemaVersion": REPORT_SCHEMA,
        "decision": "pass" if decision else "fail",
        "scope": {
            "actions": list(EXPECTED_ACTIONS),
            "actionCount": 9,
            "frameCount": 216,
        },
        "inputDigests": {
            "candidateSource": tree_digest(candidate_root),
            "package": package_digest,
            "foundationContract": sha256_file(foundation_path),
            "acceptedB2Contract": sha256_file(b2_contract_path),
        },
        "summary": {
            "customCheckCount": len(checks),
            "customFailureCount": len(failures),
            "customFailures": failures,
            "b2ObservationCount": b2_report["summary"]["observationCount"],
            "b2FindingCount": b2_report["summary"]["findingCount"],
            "b2Decision": b2_report["decision"],
        },
        "checks": checks,
        "b2ActionScopedRelease": b2_report,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-root", required=True, type=Path)
    parser.add_argument("--package-manifest", required=True, type=Path)
    parser.add_argument("--foundation-contract", required=True, type=Path)
    parser.add_argument("--b2-contract", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = validate(
        candidate_root=args.candidate_root,
        package_manifest=args.package_manifest,
        foundation_path=args.foundation_contract,
        b2_contract_path=args.b2_contract,
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_bytes(canonical_bytes(report, pretty=True))
    if report["decision"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
