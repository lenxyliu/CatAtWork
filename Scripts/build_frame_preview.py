#!/usr/bin/env python3
"""Build a contact sheet and GIF from one or more ordered frame directories."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", action="append", required=True, type=Path)
    parser.add_argument("--contact", required=True, type=Path)
    parser.add_argument("--gif", required=True, type=Path)
    parser.add_argument("--fps", type=float, default=24)
    parser.add_argument("--columns", type=int, default=8)
    args = parser.parse_args()

    paths = [path for directory in args.input_dir for path in sorted(directory.glob("*.png"))]
    if not paths:
        raise SystemExit("no PNG frames found")
    frames = [Image.open(path).convert("RGBA") for path in paths]
    content_boxes = [frame.getchannel("A").getbbox() for frame in frames]
    if any(box is None for box in content_boxes):
        raise SystemExit("empty frame detected")

    cell_width, cell_height = 220, 190
    label_height = 22
    common_scale = min(
        (cell_width - 12) / max(frame.width for frame in frames),
        (cell_height - 12) / max(frame.height for frame in frames),
        1.0,
    )
    rows = (len(frames) + args.columns - 1) // args.columns
    sheet = Image.new("RGBA", (cell_width * args.columns, (cell_height + label_height) * rows),
                      (238, 240, 243, 255))
    draw = ImageDraw.Draw(sheet)
    gif_width = max(frame.width for frame in frames)
    gif_height = max(frame.height for frame in frames)
    gif_frames: list[Image.Image] = []

    for index, frame in enumerate(frames):
        preview = frame.resize(
            (max(1, round(frame.width * common_scale)), max(1, round(frame.height * common_scale))),
            Image.Resampling.LANCZOS,
        )
        column, row = index % args.columns, index // args.columns
        x = column * cell_width + (cell_width - preview.width) // 2
        y = row * (cell_height + label_height) + cell_height - preview.height
        sheet.alpha_composite(preview, (x, y))
        draw.text((column * cell_width + 6, row * (cell_height + label_height) + cell_height + 3),
                  str(index + 1), fill=(20, 20, 22, 255))
        canvas = Image.new("RGBA", (gif_width, gif_height), (0, 0, 0, 0))
        canvas.alpha_composite(frame, ((gif_width - frame.width) // 2, gif_height - frame.height))
        gif_frames.append(canvas)

    args.contact.parent.mkdir(parents=True, exist_ok=True)
    args.gif.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.contact, optimize=True)
    gif_frames[0].save(args.gif, save_all=True, append_images=gif_frames[1:],
                       duration=round(1000 / args.fps), loop=0, disposal=2, transparency=0)
    print(f"previewed {len(frames)} frames")


if __name__ == "__main__":
    main()
