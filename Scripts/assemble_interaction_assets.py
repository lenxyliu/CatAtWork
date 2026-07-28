#!/usr/bin/env python3
"""Assemble the bounded B4 interaction slice on the frozen foundation system."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image

from assemble_foundation_assets import (
    FoundationBuildError,
    author_canvas,
    canonical_json,
    identity_view,
    load_json,
    load_take,
    sha256_file,
    write_action,
)


SCHEMA = "catatwork.interaction-build/v1"
FOUNDATION_ACTIONS = (
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
EXPECTED_ACTIONS = (
    "idleEar",
    "idleTail",
    "groom",
    "wave",
    "petting",
    "earPet",
    "chinPet",
    "backPet",
    "curious",
    "working",
    "waiting",
    "happy",
    "startled",
    "failed",
)


def action_frame_tree_digest(assets_root: Path) -> str:
    lines = []
    for action in FOUNDATION_ACTIONS:
        paths = sorted((assets_root / "frames" / action).glob("*.png"))
        if [path.name for path in paths] != [
            f"{index:03d}.png" for index in range(24)
        ]:
            raise FoundationBuildError(f"{action}: frozen foundation frames are incomplete")
        for path in paths:
            lines.append(f"{sha256_file(path)}  ./{action}/{path.name}\n")
    return hashlib.sha256("".join(lines).encode("utf-8")).hexdigest()


def seated_metadata(foundation: dict[str, Any]) -> dict[str, Any]:
    template = foundation["poseTemplates"]["seatedFront"]
    return {
        "rootAnchor": dict(template["rootAnchor"]),
        "supportAnchors": [
            {
                "id": support["id"],
                "point": dict(support["point"]),
                "contact": True,
            }
            for support in template["supportAnchors"]
        ],
    }


def action_spec(
    semantic: dict[str, Any],
    *,
    foundation: dict[str, Any],
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": semantic["id"],
        "loop": bool(semantic["loop"]),
        "fps": semantic["fps"],
        "startPose": semantic["startPose"],
        "endPose": semantic["endPose"],
        "frameMetadata": [
            seated_metadata(foundation)
            for _ in range(24)
        ],
    }
    if semantic["loop"]:
        result["loopStartFrame"] = 0
        result["nextAnimation"] = None
    for name in ("holdStartMs", "holdEndMs"):
        if name in semantic:
            result[name] = semantic[name]
    return result


def expanded_pose_order(order: list[int]) -> list[int]:
    if not order:
        raise FoundationBuildError("interaction pose order must not be empty")
    if any(
        isinstance(value, bool)
        or not isinstance(value, int)
        or value < -1
        or value > 7
        for value in order
    ):
        raise FoundationBuildError(f"invalid interaction pose order: {order}")
    if len(order) == 1:
        return order * 22
    return [
        order[(index * (len(order) - 1)) // 21]
        for index in range(22)
    ]


def canonical_endpoint_record(
    *,
    source: Path,
    role: str,
) -> dict[str, Any]:
    return {
        "derivedBy": "exact-canonical-endpoint-copy",
        "derivedFromAction": "idle",
        "derivedFromFrame": 0,
        "foundationRole": role,
        "sourceImage": str(source),
        "sourceSHA256": sha256_file(source),
        "pixelScaleChanged": False,
        "materialColorNormalization": {
            "method": "already-frozen-foundation-pixels",
            "perActionOrFrameTuning": False,
        },
    }


def build(
    *,
    draft_root: Path,
    contract_path: Path,
    foundation_path: Path,
    foundation_assets: Path,
    output_root: Path,
) -> dict[str, Any]:
    if output_root.exists():
        raise FoundationBuildError(f"output already exists: {output_root}")
    contract = load_json(contract_path)
    foundation = load_json(foundation_path)
    expected_contract_sha = contract["foundationContract"]["sha256"]
    if sha256_file(foundation_path) != expected_contract_sha:
        raise FoundationBuildError("frozen foundation contract digest changed")
    if (
        foundation.get("schemaVersion") != "catatwork.foundation/v1"
        or foundation.get("status") != "frozen"
        or foundation["canonicalScale"]["pixelsPerBodyUnit"] != 220
        or foundation["authoredCanvas"]["width"] != 665
        or foundation["authoredCanvas"]["height"] != 737
        or foundation["authoredCanvas"]["safeMargin"] != 16
        or foundation["authoredCanvas"]["colorSpace"]
        != {
            "name": "sRGB",
            "pixelFormat": "RGBA8",
            "alphaMode": "straight",
            "conversion": "identity",
        }
        or foundation["componentPolicy"].get("exceptions") != []
    ):
        raise FoundationBuildError("foundation scale/canvas/component system changed")
    if (
        contract.get("schemaVersion") != "catatwork.interaction/v1"
        or contract.get("status") != "governed"
        or tuple(contract["scope"]["actions"]) != EXPECTED_ACTIONS
        or contract["scope"]["frameCount"] != 336
        or tuple(item["id"] for item in contract["actions"]) != EXPECTED_ACTIONS
        or contract["sourcePolicy"]["resizingOrResampling"] is not False
    ):
        raise FoundationBuildError("interaction contract scope changed")
    actual_foundation_tree = action_frame_tree_digest(foundation_assets)
    if actual_foundation_tree != contract["foundationContract"]["actionFrameTreeSHA256"]:
        raise FoundationBuildError("frozen foundation action frames changed")

    canonical_source = foundation_assets / "frames" / "idle" / "000.png"
    if sha256_file(canonical_source) != contract["foundationContract"][
        "canonicalSeatedFrameSHA256"
    ]:
        raise FoundationBuildError("canonical seated endpoint changed")
    with Image.open(canonical_source) as opened:
        if (
            opened.mode != "RGBA"
            or opened.size != (665, 737)
            or opened.info.get("icc_profile")
        ):
            raise FoundationBuildError("canonical seated endpoint encoding changed")
        canonical = opened.copy()

    canvas = foundation["authoredCanvas"]
    component_policy = foundation["componentPolicy"]
    root = foundation["rootSystem"]["anatomicalRoot"]
    centroid_proxy_offset_x = float(
        foundation["rootSystem"]["alphaCentroidProxyOffsetX"]
    )
    loaded = {
        action: load_take(draft_root, action)
        for action in EXPECTED_ACTIONS
    }
    authored: dict[tuple[str, int], tuple[Image.Image, dict[str, Any]]] = {}
    for action, drafts in loaded.items():
        for draft in drafts:
            image, record = author_canvas(
                draft,
                canvas=canvas,
                root=root,
                component_policy=component_policy,
                material_references=foundation["materialReferences"],
                centroid_proxy_offset_x=centroid_proxy_offset_x,
            )
            authored[(action, draft.index)] = (
                image,
                {
                    **record,
                    "sourceAction": action,
                    "sourcePose": draft.index,
                    "pixelScaleChanged": False,
                },
            )

    output_root.mkdir(parents=True)
    build_records: dict[str, list[dict[str, Any]]] = {}
    action_images: dict[str, list[Image.Image]] = {}

    idle_directory = output_root / "frames" / "idle"
    idle_directory.mkdir(parents=True)
    idle_records = []
    idle_images = []
    for index in range(24):
        source = foundation_assets / "frames" / "idle" / f"{index:03d}.png"
        target = idle_directory / source.name
        shutil.copyfile(source, target)
        with Image.open(source) as opened:
            idle_images.append(opened.convert("RGBA"))
        idle_records.append(
            {
                "action": "idle",
                "frame": index,
                "output": str(target),
                "outputSHA256": sha256_file(target),
                "derivedBy": "exact-frozen-foundation-reference-copy",
                "sourceImage": str(source),
                "sourceSHA256": sha256_file(source),
                "pixelScaleChanged": False,
                "productionScope": False,
            }
        )
    action_images["idle"] = idle_images
    build_records["idle"] = idle_records

    semantics = {item["id"]: item for item in contract["actions"]}
    for action in EXPECTED_ACTIONS:
        order = expanded_pose_order(semantics[action]["poseOrder"])
        middle_images: list[Image.Image] = []
        middle_records: list[dict[str, Any]] = []
        for source_pose in order:
            if source_pose == -1:
                middle_images.append(canonical)
                middle_records.append(
                    canonical_endpoint_record(
                        source=canonical_source,
                        role="canonical-seated-inbetween",
                    )
                )
            else:
                image, record = authored[(action, source_pose)]
                middle_images.append(image)
                middle_records.append(
                    {
                        **record,
                        "foundationRole": "interaction-authored-inbetween",
                    }
                )
        frames = [canonical, *middle_images, canonical]
        records = [
            canonical_endpoint_record(
                source=canonical_source,
                role="canonical-seated-start-endpoint",
            ),
            *middle_records,
            canonical_endpoint_record(
                source=canonical_source,
                role="canonical-seated-end-endpoint",
            ),
        ]
        action_images[action], build_records[action] = write_action(
            output_root,
            action,
            frames,
            records,
        )

    sheet_views = {
        item["id"]: item
        for item in foundation["identitySheet"]["views"]
    }
    identity_rig = {
        "views": [
            identity_view(
                identifier="front",
                sheet_view=sheet_views["front"],
                reference_action="idle",
                reference_frame=0,
                reference_image=action_images["idle"][0],
                canvas=canvas,
            )
        ]
    }
    idle_semantic = next(
        item for item in foundation["actionSemantics"] if item["id"] == "idle"
    )
    spec = {
        "contractVersion": 2,
        "petId": "cat-at-work",
        "displayName": "猫上班了",
        "author": "猫上班了",
        "description": "B4 interaction production slice; partial non-release package.",
        "minimumAppVersion": "1.0.0",
        "assetVersion": "2026.07.28.interaction.1",
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
            action_spec(idle_semantic, foundation=foundation),
            *[
                action_spec(semantics[action], foundation=foundation)
                for action in EXPECTED_ACTIONS
            ],
        ],
    }
    spec_path = output_root / "animation-spec.json"
    spec_path.write_bytes(canonical_json(spec))

    report = {
        "schemaVersion": SCHEMA,
        "interactionContract": {
            "path": str(contract_path),
            "sha256": sha256_file(contract_path),
        },
        "foundationContract": {
            "path": str(foundation_path),
            "sha256": sha256_file(foundation_path),
            "actionFrameTreeSHA256": actual_foundation_tree,
            "canonicalSeatedFrameSHA256": sha256_file(canonical_source),
        },
        "sourceSheetSize": [
            contract["sourcePolicy"]["sheetSize"]["width"],
            contract["sourcePolicy"]["sheetSize"]["height"],
        ],
        "pixelOperations": contract["sourcePolicy"]["allowedPixelOperations"],
        "resizingOrResampling": False,
        "actions": {
            action: build_records[action]
            for action in EXPECTED_ACTIONS
        },
        "foundationReference": {
            "action": "idle",
            "frames": build_records["idle"],
            "productionScope": False,
        },
        "summary": {
            "actionCount": 14,
            "frameCount": 336,
            "referenceFrameCount": 24,
            "canvas": [canvas["width"], canvas["height"]],
            "pixelsPerBodyUnit": foundation["canonicalScale"][
                "pixelsPerBodyUnit"
            ],
            "componentExceptions": len(component_policy["exceptions"]),
        },
        "animationSpecSHA256": sha256_file(spec_path),
    }
    report_path = output_root / "interaction-build-report.json"
    report_path.write_bytes(canonical_json(report))
    return {
        "output": str(output_root),
        "spec": str(spec_path),
        "report": str(report_path),
        "frameCount": report["summary"]["frameCount"],
        "referenceFrameCount": report["summary"]["referenceFrameCount"],
    }


def install(candidate_root: Path, assets_root: Path) -> dict[str, Any]:
    report = load_json(candidate_root / "interaction-build-report.json")
    if (
        report.get("schemaVersion") != SCHEMA
        or report.get("summary", {}).get("frameCount") != 336
        or report.get("resizingOrResampling") is not False
    ):
        raise FoundationBuildError("interaction candidate report is not installable")
    targets: list[Path] = []
    for action in EXPECTED_ACTIONS:
        source_dir = candidate_root / "frames" / action
        paths = sorted(source_dir.glob("*.png"))
        if [path.name for path in paths] != [
            f"{index:03d}.png" for index in range(24)
        ]:
            raise FoundationBuildError(f"{action}: candidate is incomplete")
        target_dir = assets_root / "frames" / action
        if not target_dir.is_dir() or len(list(target_dir.glob("*.png"))) != 24:
            raise FoundationBuildError(
                f"{action}: production target is not the expected 24 frames"
            )
        for source in paths:
            target = target_dir / source.name
            shutil.copyfile(source, target)
            targets.append(target)
    return {
        "installedFrames": len(targets),
        "actions": list(EXPECTED_ACTIONS),
        "productionSpecModified": False,
        "productionSpec": str(assets_root / "animation-spec.json"),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--draft-root", required=True, type=Path)
    parser.add_argument("--interaction-contract", required=True, type=Path)
    parser.add_argument("--foundation-contract", required=True, type=Path)
    parser.add_argument("--foundation-assets", required=True, type=Path)
    parser.add_argument("--output-root", type=Path)
    parser.add_argument("--install-assets-root", type=Path)
    args = parser.parse_args()
    if (args.output_root is None) == (args.install_assets_root is None):
        parser.error("choose exactly one of --output-root or --install-assets-root")
    return args


def main() -> None:
    args = parse_args()
    if args.output_root is not None:
        result = build(
            draft_root=args.draft_root,
            contract_path=args.interaction_contract,
            foundation_path=args.foundation_contract,
            foundation_assets=args.foundation_assets,
            output_root=args.output_root,
        )
    else:
        result = install(args.draft_root, args.install_assets_root)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
