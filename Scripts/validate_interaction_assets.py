#!/usr/bin/env python3
"""Validate the bounded B4 interaction candidate against frozen B2/B3 gates."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image

from assemble_foundation_assets import connected_component_areas
from assemble_interaction_assets import (
    EXPECTED_ACTIONS,
    action_frame_tree_digest,
)
from build_foundation_qa import head_proxy
from validate_visual_qa import (
    canonical_bytes,
    evaluate_observations,
    image_digest,
    scan_static,
    sha256_file,
    tree_digest,
)


REPORT_SCHEMA = "catatwork.interaction-validation/v1"
SCAN_ACTIONS = ("idle", *EXPECTED_ACTIONS)


class InteractionValidationError(ValueError):
    """The interaction candidate cannot be evaluated against the governed scope."""


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
    scope = set(SCAN_ACTIONS)
    projected["actionContracts"] = [
        {
            **group,
            "actions": [
                action for action in group["actions"] if action in scope
            ],
        }
        for group in projected["actionContracts"]
        if any(action in scope for action in group["actions"])
    ]
    return projected


def frame_paths(candidate_root: Path, action: str) -> list[Path]:
    paths = sorted((candidate_root / "frames" / action).glob("*.png"))
    if [path.name for path in paths] != [
        f"{index:03d}.png" for index in range(24)
    ]:
        raise InteractionValidationError(
            f"{action}: expected frames 000.png through 023.png"
        )
    return paths


def rgba_digest(path: Path) -> str:
    with Image.open(path) as opened:
        if opened.mode != "RGBA":
            raise InteractionValidationError(f"{path}: expected RGBA")
        return image_digest(opened.convert("RGBA"))


def exact_endpoint_check(candidate_root: Path) -> dict[str, Any]:
    reference = rgba_digest(candidate_root / "frames" / "idle" / "000.png")
    mismatches = []
    measurements = {}
    for action in EXPECTED_ACTIONS:
        digests = {
            "start": rgba_digest(
                candidate_root / "frames" / action / "000.png"
            ),
            "end": rgba_digest(
                candidate_root / "frames" / action / "023.png"
            ),
        }
        measurements[action] = digests
        for endpoint, digest in digests.items():
            if digest != reference:
                mismatches.append(
                    {
                        "action": action,
                        "endpoint": endpoint,
                        "digest": digest,
                    }
                )
    return {
        "id": "semantics/exact-seated-endpoints-and-bridges",
        "passed": not mismatches,
        "canonicalIdleRGBA": reference,
        "measurements": measurements,
        "mismatches": mismatches,
    }


def extraction_check(
    draft_root: Path,
    *,
    interaction: dict[str, Any],
) -> dict[str, Any]:
    expected_size = [
        interaction["sourcePolicy"]["sheetSize"]["width"],
        interaction["sourcePolicy"]["sheetSize"]["height"],
    ]
    failures = []
    measurements = {}
    for action in EXPECTED_ACTIONS:
        path = draft_root / f"{action}.json"
        report = load_json(path)
        frames = report.get("frames") or []
        measurements[action] = {
            "report": str(path),
            "sourceSize": report.get("sourceSize"),
            "frameCount": len(frames),
            "assignedComponents": [
                frame.get("assignedComponents") for frame in frames
            ],
            "minimumBoundaryClearance": min(
                (frame.get("boundaryClearance", -1) for frame in frames),
                default=-1,
            ),
        }
        if (
            report.get("ok") is not True
            or report.get("sourceSize") != expected_size
            or report.get("layout") != {"rows": 2, "columns": 4}
            or len(frames) != 8
            or [frame.get("index") for frame in frames] != list(range(8))
            or any(
                frame.get("pixelScaleChanged") is not False
                or frame.get("assignedComponents") != 1
                for frame in frames
            )
        ):
            failures.append(action)
    return {
        "id": "source/eight-pose-native-sheet-extraction",
        "passed": not failures,
        "expectedSheetSize": expected_size,
        "measurements": measurements,
        "failedActions": failures,
    }


def provenance_check(
    build_report: dict[str, Any],
) -> dict[str, Any]:
    actions = build_report.get("actions") or {}
    records = [
        record
        for action in EXPECTED_ACTIONS
        for record in actions.get(action, [])
    ]
    failures = []
    for action in EXPECTED_ACTIONS:
        action_records = actions.get(action, [])
        if len(action_records) != 24:
            failures.append(
                {"action": action, "reason": "frame-count"}
            )
        for index, record in enumerate(action_records):
            if record.get("pixelScaleChanged") is not False:
                failures.append(
                    {
                        "action": action,
                        "frame": index,
                        "reason": "scale-changed",
                    }
                )
    allowed = {
        "chroma-key",
        "connected-pose-extraction",
        "transparent-padding-crop",
        "integer-translation-to-authored-canvas",
        "fixed-canonical-material-palette-pull",
        "exact-canonical-endpoint-copy",
    }
    if (
        len(records) != 336
        or build_report.get("resizingOrResampling") is not False
        or set(build_report.get("pixelOperations") or []) != allowed
    ):
        failures.append({"reason": "build-summary-or-operation-policy"})
    return {
        "id": "source/336-frames-no-resize-or-resample",
        "passed": not failures,
        "frameRecordCount": len(records),
        "resizingOrResampling": build_report.get("resizingOrResampling"),
        "pixelOperations": build_report.get("pixelOperations"),
        "failures": failures,
    }


def component_check(
    candidate_root: Path,
    *,
    foundation: dict[str, Any],
) -> dict[str, Any]:
    policy = foundation["componentPolicy"]
    failures = []
    maximum_count = 0
    for action in EXPECTED_ACTIONS:
        for index, path in enumerate(frame_paths(candidate_root, action)):
            with Image.open(path) as opened:
                areas = connected_component_areas(
                    opened.getchannel("A"),
                    threshold=int(policy["alphaThreshold"]),
                    minimum_area=int(policy["minimumArea"]),
                )
            maximum_count = max(maximum_count, len(areas))
            if len(areas) != 1:
                failures.append(
                    {
                        "action": action,
                        "frame": index,
                        "areas": areas,
                    }
                )
    return {
        "id": "component/all-interaction-anatomy-connected",
        "passed": not failures and policy.get("exceptions") == [],
        "maximumSignificantComponentCount": maximum_count,
        "foundationExceptions": policy.get("exceptions"),
        "failures": failures,
    }


def seated_support_check(
    candidate_root: Path,
    *,
    foundation: dict[str, Any],
) -> dict[str, Any]:
    support_y = int(foundation["rootSystem"]["supportLineY"])
    failures = []
    bounds = {}
    for action in EXPECTED_ACTIONS:
        action_bounds = []
        for index, path in enumerate(frame_paths(candidate_root, action)):
            with Image.open(path) as opened:
                bbox = opened.getchannel("A").getbbox()
            action_bounds.append(bbox)
            if bbox is None or bbox[3] != support_y:
                failures.append(
                    {
                        "action": action,
                        "frame": index,
                        "bounds": bbox,
                    }
                )
        bounds[action] = action_bounds
    return {
        "id": "root/all-frames-frozen-seated-support",
        "passed": not failures,
        "expectedSupportLineY": support_y,
        "bounds": bounds,
        "failures": failures,
    }


def direction_check(
    candidate_root: Path,
    *,
    build_report: dict[str, Any],
    interaction: dict[str, Any],
    runtime_source: Path,
) -> dict[str, Any]:
    policy = interaction["interactionDirectionPolicy"]
    with Image.open(
        candidate_root / "frames" / "idle" / "000.png"
    ) as opened:
        idle = opened.convert("RGBA")
    idle_x = head_proxy(idle)[0]
    minimum = float(policy["minimumHeadProxyDeltaPixels"])
    measurements = {}
    failures = []
    for action, expected in policy["actions"].items():
        records = build_report["actions"][action]
        candidates = [
            index
            for index, record in enumerate(records)
            if record.get("sourcePose") == expected["sourcePose"]
        ]
        if not candidates:
            failures.append(
                {"action": action, "reason": "source-pose-not-selected"}
            )
            continue
        frame_index = candidates[len(candidates) // 2]
        with Image.open(
            candidate_root / "frames" / action / f"{frame_index:03d}.png"
        ) as opened:
            right = opened.convert("RGBA")
        left = right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        mirrored_idle = idle.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        right_delta = head_proxy(right)[0] - idle_x
        left_delta = head_proxy(left)[0] - head_proxy(mirrored_idle)[0]
        double_mirrored = left.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        measurements[action] = {
            "frame": frame_index,
            "sourcePose": expected["sourcePose"],
            "baseHeadProxyDeltaX": round(right_delta, 6),
            "mirroredHeadProxyDeltaX": round(left_delta, 6),
            "doubleMirrorExact": image_digest(double_mirrored)
            == image_digest(right),
        }
        if (
            right_delta < minimum
            or left_delta > -minimum
            or image_digest(double_mirrored) != image_digest(right)
        ):
            failures.append(
                {
                    "action": action,
                    **measurements[action],
                }
            )
    source_text = runtime_source.read_text(encoding="utf-8")
    runtime_tokens = (
        "interactionFacesLeft = lockedLeft",
        "flipHorizontally: interactionDirectionUntil > CACurrentMediaTime() && interactionFacesLeft",
    )
    missing_tokens = [
        token for token in runtime_tokens if token not in source_text
    ]
    if missing_tokens:
        failures.append(
            {
                "reason": "runtime-mirror-contract-changed",
                "missingTokens": missing_tokens,
            }
        )
    return {
        "id": "semantics/interaction-direction-and-runtime-mirror",
        "passed": not failures,
        "minimumHeadProxyDeltaPixels": minimum,
        "measurements": measurements,
        "runtimeSource": str(runtime_source),
        "runtimeSourceSHA256": sha256_file(runtime_source),
        "failures": failures,
    }


def foundation_check(
    foundation_assets: Path,
    *,
    foundation_path: Path,
    interaction: dict[str, Any],
) -> dict[str, Any]:
    actual_contract = sha256_file(foundation_path)
    actual_tree = action_frame_tree_digest(foundation_assets)
    canonical = foundation_assets / "frames" / "idle" / "000.png"
    actual_canonical = sha256_file(canonical)
    expected = interaction["foundationContract"]
    return {
        "id": "foundation/frozen-nine-actions-unchanged",
        "passed": (
            actual_contract == expected["sha256"]
            and actual_tree == expected["actionFrameTreeSHA256"]
            and actual_canonical == expected["canonicalSeatedFrameSHA256"]
        ),
        "actual": {
            "contractSHA256": actual_contract,
            "actionFrameTreeSHA256": actual_tree,
            "canonicalSeatedFrameSHA256": actual_canonical,
        },
        "expected": expected,
    }


def validate(
    *,
    candidate_root: Path,
    draft_root: Path,
    package_manifest: Path,
    interaction_path: Path,
    foundation_path: Path,
    foundation_assets: Path,
    b2_contract_path: Path,
    runtime_source: Path,
) -> dict[str, Any]:
    interaction = load_json(interaction_path)
    foundation = load_json(foundation_path)
    build_report = load_json(
        candidate_root / "interaction-build-report.json"
    )
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
            "scope": list(SCAN_ACTIONS),
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
            "interactionContract": sha256_file(interaction_path),
            "interactionBuildReport": sha256_file(
                candidate_root / "interaction-build-report.json"
            ),
        },
    )
    checks = [
        foundation_check(
            foundation_assets,
            foundation_path=foundation_path,
            interaction=interaction,
        ),
        extraction_check(draft_root, interaction=interaction),
        provenance_check(build_report),
        exact_endpoint_check(candidate_root),
        component_check(candidate_root, foundation=foundation),
        seated_support_check(candidate_root, foundation=foundation),
        direction_check(
            candidate_root,
            build_report=build_report,
            interaction=interaction,
            runtime_source=runtime_source,
        ),
    ]
    failures = [check["id"] for check in checks if not check["passed"]]
    decision = b2_report["decision"] == "pass" and not failures
    return {
        "schemaVersion": REPORT_SCHEMA,
        "decision": "pass" if decision else "fail",
        "scope": {
            "actions": list(EXPECTED_ACTIONS),
            "actionCount": 14,
            "frameCount": 336,
            "scanReferenceActions": ["idle"],
        },
        "inputDigests": {
            "candidateSource": tree_digest(candidate_root),
            "draftSource": tree_digest(draft_root),
            "package": package_digest,
            "foundationContract": sha256_file(foundation_path),
            "interactionContract": sha256_file(interaction_path),
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
    parser.add_argument("--draft-root", required=True, type=Path)
    parser.add_argument("--package-manifest", required=True, type=Path)
    parser.add_argument("--interaction-contract", required=True, type=Path)
    parser.add_argument("--foundation-contract", required=True, type=Path)
    parser.add_argument("--foundation-assets", required=True, type=Path)
    parser.add_argument("--b2-contract", required=True, type=Path)
    parser.add_argument("--runtime-source", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = validate(
        candidate_root=args.candidate_root,
        draft_root=args.draft_root,
        package_manifest=args.package_manifest,
        interaction_path=args.interaction_contract,
        foundation_path=args.foundation_contract,
        foundation_assets=args.foundation_assets,
        b2_contract_path=args.b2_contract,
        runtime_source=args.runtime_source,
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_bytes(canonical_bytes(report, pretty=True))
    if report["decision"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
