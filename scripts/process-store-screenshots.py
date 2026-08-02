#!/usr/bin/env python3
"""Convert live Airo captures into store-compliant, privacy-safe RGB PNGs."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageOps


BACKGROUND = (15, 23, 42)
MIN_DIMENSION = 320
MAX_DIMENSION = 3840


def store_ready(image: Image.Image) -> Image.Image:
    rgb = Image.new("RGB", image.size, BACKGROUND)
    if "A" in image.getbands():
        rgb.paste(image, mask=image.getchannel("A"))
    else:
        rgb.paste(image.convert("RGB"))

    width, height = rgb.size
    long_edge = max(width, height)
    short_edge = min(width, height)
    if long_edge > 2 * short_edge:
        required_short_edge = math.ceil(long_edge / 2)
        target = (
            (required_short_edge, height)
            if width < height
            else (width, required_short_edge)
        )
        padded = Image.new("RGB", target, BACKGROUND)
        padded.paste(
            rgb,
            ((target[0] - width) // 2, (target[1] - height) // 2),
        )
        rgb = padded
    validate(rgb)
    return rgb


def validate(image: Image.Image, *, enforce_screenshot_ratio: bool = True) -> None:
    width, height = image.size
    if image.mode != "RGB":
        raise ValueError(f"expected RGB image, got {image.mode}")
    if min(width, height) < MIN_DIMENSION:
        raise ValueError(f"minimum dimension is below {MIN_DIMENSION}: {image.size}")
    if max(width, height) > MAX_DIMENSION:
        raise ValueError(f"maximum dimension exceeds {MAX_DIMENSION}: {image.size}")
    if enforce_screenshot_ratio and max(width, height) > 2 * min(width, height):
        raise ValueError(f"aspect ratio exceeds 2:1: {image.size}")


def process(args: argparse.Namespace) -> list[dict[str, object]]:
    args.output_dir.mkdir(parents=True, exist_ok=True)
    args.feature_output.parent.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, object]] = []
    sources = sorted(args.input_dir.glob("*.png"))
    if not sources:
        raise ValueError(f"no PNG screenshots found in {args.input_dir}")
    for source in sources:
        with Image.open(source) as opened:
            image = store_ready(opened)
        target = args.output_dir / source.name
        image.save(target, format="PNG", optimize=True)
        manifest.append(_record(target, image, "runtime-screenshot"))

    feature = ImageOps.fit(
        Image.open(args.feature_source).convert("RGB"),
        (1024, 500),
        method=Image.Resampling.LANCZOS,
        centering=(0.58, 0.5),
    )
    if feature.size != (1024, 500):
        raise ValueError(f"feature graphic must be exactly 1024x500: {feature.size}")
    validate(feature, enforce_screenshot_ratio=False)
    feature.save(args.feature_output, format="PNG", optimize=True)
    manifest.append(_record(args.feature_output, feature, "feature-graphic"))

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(
        json.dumps({"schemaVersion": 1, "assets": manifest}, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def _record(path: Path, image: Image.Image, kind: str) -> dict[str, object]:
    return {
        "filename": path.name,
        "kind": kind,
        "width": image.width,
        "height": image.height,
        "colorMode": image.mode,
        "alpha": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--feature-source", type=Path, required=True)
    parser.add_argument("--feature-output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args()


if __name__ == "__main__":
    parsed = parse_args()
    records = process(parsed)
    print(f"Processed {len(records)} store assets")
