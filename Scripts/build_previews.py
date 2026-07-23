#!/usr/bin/env python3
"""Create deterministic contact sheets and looping GIF previews for every action."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


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
        "width": max(1, math.ceil(left + right + margin * 2)),
        "height": max(1, math.ceil(top + bottom + margin * 2)),
        "anchorX": margin + left,
        "anchorY": margin + top,
    }


def load_frame(root: Path, frame: dict) -> Image.Image:
    image = Image.open(root / frame["image"]).convert("RGBA")
    if rect := frame.get("textureRect"):
        image = image.crop((rect["x"], rect["y"], rect["x"] + rect["width"], rect["y"] + rect["height"]))
    scale = frame.get("bodyScale", 1.0)
    if scale != 1:
        image = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.Resampling.LANCZOS,
        )
    return image


def place_frame(source: Image.Image, frame: dict, layout: dict) -> Image.Image:
    canvas = Image.new("RGBA", (layout["width"], layout["height"]), (0, 0, 0, 0))
    scale = frame.get("bodyScale", 1.0)
    pivot = frame["pivot"]
    offset = frame.get("renderOffset") or {"x": 0, "y": 0}
    x = round(layout["anchorX"] - pivot["x"] * frame["sourceSize"]["width"] * scale + offset["x"] * scale)
    y = round(layout["anchorY"] - pivot["y"] * frame["sourceSize"]["height"] * scale + offset["y"] * scale)
    canvas.alpha_composite(source, (x, y))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    root = args.manifest.parent
    args.output.mkdir(parents=True, exist_ok=True)
    overview_cards = []
    all_frames = [frame for animation in manifest["animations"] for frame in animation["frames"]]
    all_frames += [direction["frame"] for direction in manifest.get("lookDirections", [])]
    layout = canvas_layout(all_frames)
    (args.output / "runtime-canvas.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n")

    for animation in manifest["animations"]:
        images = [load_frame(root, frame) for frame in animation["frames"]]
        runtime_frames = [place_frame(image, frame, layout) for image, frame in zip(images, animation["frames"])]
        cell_w = layout["width"]
        cell_h = layout["height"]
        thumb_scale = min(1.0, 180 / cell_h, 220 / cell_w)
        tw, th = max(1, round(cell_w * thumb_scale)), max(1, round(cell_h * thumb_scale))
        sheet = Image.new("RGBA", (tw * 8, (th + 22) * 3), (245, 246, 248, 255))
        draw = ImageDraw.Draw(sheet)
        gif_frames = []
        for index, runtime_frame in enumerate(runtime_frames):
            # This is the exact runtime placement: global shared anchor, global
            # scale and the same variable source sizes used by MetalPetView.
            resized = runtime_frame.resize(
                (max(1, round(runtime_frame.width * thumb_scale)), max(1, round(runtime_frame.height * thumb_scale))),
                Image.Resampling.LANCZOS,
            )
            x = (index % 8) * tw
            y = (index // 8) * (th + 22)
            sheet.alpha_composite(resized, (x, y))
            label_color = (176, 35, 35, 255) if index in {7, 8, 15, 16, 23} else (20, 20, 20, 255)
            draw.rectangle(((index % 8) * tw, (index // 8) * (th + 22), (index % 8 + 1) * tw - 1,
                            (index // 8) * (th + 22) + th - 1), outline=(185, 188, 194, 255))
            draw.text(((index % 8) * tw + 5, (index // 8) * (th + 22) + th + 3), str(index + 1), fill=label_color)
            gif_frames.append(runtime_frame)
        sheet.save(args.output / f"{animation['id']}-contact.png")
        card = sheet.copy()
        card.thumbnail((520, 310), Image.Resampling.LANCZOS)
        labeled = Image.new("RGBA", (520, 340), (235, 237, 240, 255))
        labeled.alpha_composite(card, ((520 - card.width) // 2, 28))
        ImageDraw.Draw(labeled).text((8, 7), animation["id"], fill=(15, 15, 18, 255))
        overview_cards.append(labeled)
        durations = [round(frame["duration"] * 1000) for frame in animation["frames"]]
        loop_start = min(max(int(animation.get("loopStartFrame") or 0), 0), len(gif_frames) - 1)
        if animation.get("loopMode") == "loop" and loop_start > 0:
            # Intro+loop actions must be reviewed with the same loop boundary
            # used by AnimationPlayer, never with a false 24->1 snap.
            gif_frames[0].save(args.output / f"{animation['id']}-intro.gif", save_all=True,
                               append_images=gif_frames[1:], duration=durations, loop=1,
                               disposal=2, transparency=0)
            loop_frames = gif_frames[loop_start:]
            loop_durations = durations[loop_start:]
            loop_frames[0].save(args.output / f"{animation['id']}.gif", save_all=True,
                                append_images=loop_frames[1:], duration=loop_durations, loop=0,
                                disposal=2, transparency=0)
        else:
            gif_frames[0].save(args.output / f"{animation['id']}.gif", save_all=True,
                               append_images=gif_frames[1:], duration=durations, loop=0,
                               disposal=2, transparency=0)

    if overview_cards:
        columns = 3
        rows = (len(overview_cards) + columns - 1) // columns
        overview = Image.new("RGBA", (520 * columns, 340 * rows), (225, 227, 231, 255))
        for index, card in enumerate(overview_cards):
            overview.alpha_composite(card, ((index % columns) * 520, (index // columns) * 340))
        overview.save(args.output / "all-actions-contact.png")


if __name__ == "__main__":
    main()
