#!/usr/bin/env python3
"""Build a safe development or release .catpet directory from validated frames."""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

from PIL import Image


NUMBERED_FRAME = re.compile(r"^[0-9]{3}\.png$")


def numbered_frame_paths(frame_dir: Path) -> list[Path]:
    """Return only one contiguous 000... frame sequence.

    Default-pet authoring strips live below ``generated/`` and are never valid
    runtime inputs. Requiring numbered files here also prevents a forgotten
    strip/contact sheet from silently becoming a 25th animation frame.
    """
    if not frame_dir.is_dir():
        return []
    pngs = sorted(frame_dir.glob("*.png"))
    invalid = [path.name for path in pngs if NUMBERED_FRAME.fullmatch(path.name) is None]
    if invalid:
        raise SystemExit(f"non-frame PNGs in {frame_dir}: {', '.join(invalid)}")
    expected = [f"{index:03d}.png" for index in range(len(pngs))]
    actual = [path.name for path in pngs]
    if actual != expected:
        raise SystemExit(f"non-contiguous frame numbering in {frame_dir}: expected {expected}, got {actual}")
    return pngs


def pack_atlas(images: list[Image.Image], output: Path, max_width: int = 4096, gap: int = 4):
    """Shelf-pack variable rectangles without rescaling and return their atlas rectangles."""
    positions = []
    x = y = row_height = used_width = 0
    for image in images:
        if image.width > max_width:
            raise SystemExit(f"frame wider than atlas limit: {image.width}px")
        if x and x + image.width > max_width:
            y += row_height + gap
            x = 0
            row_height = 0
        positions.append((x, y, image.width, image.height))
        x += image.width + gap
        used_width = max(used_width, x - gap)
        row_height = max(row_height, image.height)
    used_height = y + row_height
    if used_height > 8192:
        raise SystemExit(f"atlas exceeds 8192px height: {used_height}px")
    atlas = Image.new("RGBA", (used_width, used_height), (0, 0, 0, 0))
    for image, (px, py, _, _) in zip(images, positions):
        atlas.alpha_composite(image, (px, py))
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, optimize=True)
    return positions


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets-root", type=Path, default=Path("Assets/CatAtWork"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--require-all", action="store_true")
    parser.add_argument(
        "--legacy-v1",
        action="store_true",
        help="explicitly reproduce the legacy format-1 resize/pivot pipeline",
    )
    args = parser.parse_args()

    spec = json.loads((args.assets_root / "animation-spec.json").read_text())
    if spec.get("contractVersion") == 2:
        if args.legacy_v1:
            raise SystemExit("--legacy-v1 cannot be used with contractVersion 2")
        from canonical_asset_contract import (  # pylint: disable=import-outside-toplevel
            CanonicalAssetContractError,
            build_canonical_package,
        )

        try:
            result = build_canonical_package(
                args.assets_root,
                args.output,
                require_all=args.require_all,
            )
        except CanonicalAssetContractError as error:
            raise SystemExit(str(error)) from error
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return
    if not args.legacy_v1:
        raise SystemExit(
            "legacy authoring spec requires explicit --legacy-v1; "
            "the builder will not silently upgrade or rewrite format 1"
        )
    complete = []
    missing = []
    minimum_frames = int(spec.get("minimumFramesPerAnimation", 24))
    for action in spec["actions"]:
        frame_dir = args.assets_root / "frames" / action["id"]
        paths = numbered_frame_paths(frame_dir)
        if len(paths) < minimum_frames:
            missing.append(f"{action['id']} ({len(paths)}/{minimum_frames})")
            continue
        offsets = action.get("renderOffsets")
        if offsets is not None and len(offsets) != len(paths):
            raise SystemExit(
                f"{action['id']}: renderOffsets has {len(offsets)} entries for {len(paths)} frames"
            )
        complete.append((action, paths))

    if args.require_all and missing:
        raise SystemExit("incomplete animations: " + ", ".join(missing))
    if not complete:
        raise SystemExit("no complete animations")

    if args.output.exists():
        shutil.rmtree(args.output)
    args.output.mkdir(parents=True)
    animations = []
    for action, paths in complete:
        prepared = []
        for source in paths:
            image = Image.open(source).convert("RGBA")
            authoring_scale = action.get("authoringScale", 1.0)
            if authoring_scale != 1.0:
                image = image.resize((round(image.width * authoring_scale), round(image.height * authoring_scale)),
                                     Image.Resampling.LANCZOS)
            prepared.append(image)
        atlas_relative = Path("atlases") / f"{action['id']}.png"
        positions = pack_atlas(prepared, args.output / atlas_relative)
        frames = []
        for frame_index, (image, texture_rect, source) in enumerate(zip(prepared, positions, paths)):
            bbox = image.getchannel("A").getbbox()
            if bbox is None:
                raise SystemExit(f"empty frame: {source}")
            width, height = image.size
            if action.get("pivotMode") == "bodyCenter":
                # Airborne tumble frames rotate around the torso, not whichever
                # paw or tail happens to be the lowest opaque pixel that frame.
                foot_x = ((bbox[0] + bbox[2]) / 2) / width
                foot_y = ((bbox[1] + bbox[3]) / 2) / height
            else:
                foot_x = ((bbox[0] + bbox[2]) / 2) / width
                foot_y = bbox[3] / height
            frame = {
                "image": str(atlas_relative),
                "sourceSize": {"width": width, "height": height},
                "trimRect": {"x": bbox[0], "y": bbox[1], "width": bbox[2] - bbox[0], "height": bbox[3] - bbox[1]},
                "textureRect": {"x": texture_rect[0], "y": texture_rect[1], "width": texture_rect[2], "height": texture_rect[3]},
                "collisionRect": {"x": bbox[0], "y": bbox[1], "width": bbox[2] - bbox[0], "height": bbox[3] - bbox[1]},
                "pivot": {"x": foot_x, "y": foot_y},
                "duration": 1 / action["fps"] + (
                    action.get("holdStartMs", 0) / 1000 if frame_index == 0 else 0
                ) + (
                    action.get("holdEndMs", 0) / 1000 if frame_index == len(prepared) - 1 else 0
                ),
                "bodyScale": 1.0,
            }
            if offsets := action.get("renderOffsets"):
                offset = offsets[frame_index]
                if not isinstance(offset, dict) or set(offset) != {"x", "y"}:
                    raise SystemExit(f"{action['id']}: renderOffset {frame_index} must contain x and y")
                frame["renderOffset"] = {
                    "x": float(offset["x"]) * authoring_scale,
                    "y": float(offset["y"]) * authoring_scale,
                }
            frames.append(frame)
        animations.append({
            "id": action["id"],
            "loopMode": "loop" if action["loop"] else "once",
            "nextAnimation": None if action["loop"] else "idle",
            "startPose": action.get("startPose"),
            "endPose": action.get("endPose"),
            "loopStartFrame": action.get("loopStartFrame"),
            "frames": frames,
        })

    look_directions = []
    look_sources = sorted((args.assets_root / "frames" / "lookDirections").glob("*.png"))
    if look_sources and len(look_sources) != 16:
        raise SystemExit(f"look direction library must contain 16 frames, found {len(look_sources)}")
    look_images = [Image.open(source).convert("RGBA") for source in look_sources]
    look_atlas_relative = Path("atlases/lookDirections.png")
    look_positions = pack_atlas(look_images, args.output / look_atlas_relative) if look_images else []
    for index, (source, image, texture_rect) in enumerate(zip(look_sources, look_images, look_positions)):
        bbox = image.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"empty look direction frame: {source}")
        width, height = image.size
        frame = {
            "image": str(look_atlas_relative),
            "sourceSize": {"width": width, "height": height},
            "trimRect": {"x": bbox[0], "y": bbox[1], "width": bbox[2] - bbox[0], "height": bbox[3] - bbox[1]},
            "textureRect": {"x": texture_rect[0], "y": texture_rect[1], "width": texture_rect[2], "height": texture_rect[3]},
            "collisionRect": {"x": bbox[0], "y": bbox[1], "width": bbox[2] - bbox[0], "height": bbox[3] - bbox[1]},
            "pivot": {"x": ((bbox[0] + bbox[2]) / 2) / width, "y": bbox[3] / height},
            "duration": 1 / 24,
            "bodyScale": 1.0,
        }
        look_directions.append({"degrees": index * 22.5, "frame": frame})

    thumbnail = args.assets_root / "identity" / "thumbnail.png"
    if not thumbnail.exists():
        thumbnail = args.assets_root / "identity" / "canonical-turnaround.png"
    if thumbnail.exists():
        shutil.copy2(thumbnail, args.output / "thumbnail.png")
    manifest = {
        "formatVersion": 1,
        "id": spec["petId"],
        "displayName": spec["displayName"],
        "author": "猫上班了",
        "description": "陪你认真工作，也会偷偷舔毛的活泼长毛猫。",
        "minimumAppVersion": "1.0.0",
        "assetVersion": spec.get("assetVersion", "development"),
        "pixelsPerBodyUnit": spec["pixelsPerBodyUnit"],
        "animations": animations,
        "lookDirections": look_directions,
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"output": str(args.output), "complete": len(complete), "missing": missing}, ensure_ascii=False))


if __name__ == "__main__":
    main()
