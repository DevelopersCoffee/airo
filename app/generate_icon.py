#!/usr/bin/env python3
"""
Generate Airo app icons using Pillow (PIL).
No runtime pip installs. Fail fast if Pillow missing.

Usage:
  python gen_icons.py [--base app]  # optional base path prefix
"""

import sys
import os
import argparse
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError as e:
    print("Error: Pillow not installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(1)


# --------- drawing ----------

def _clamp(v):  # avoid overflow
    return max(0, min(255, int(v)))


def _lerp(a, b, t):
    return a + (b - a) * t


def _gradient_row_color(t):
    # top -> bottom blue gradient (adjusted to be in-gamut)
    r = _clamp(_lerp(33, 13, t))
    g = _clamp(_lerp(150, 118, t))
    b = _clamp(_lerp(243, 161, t))
    return (r, g, b, 255)


def _draw_background(img):
    """Fast vertical gradient fill."""
    w, h = img.size
    draw = ImageDraw.Draw(img)
    denom = max(1, h - 1)
    for y in range(h):
        t = y / denom
        draw.line([(0, y), (w, y)], fill=_gradient_row_color(t))


def _aa_line(draw, p1, p2, fill, width):
    # Pillow's line has okay AA for wide lines; keep integer coords
    draw.line([p1, p2], fill=fill, width=width, joint="curve")


def create_icon(size: int) -> Image.Image:
    """Create square RGBA icon."""
    size = int(size)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    _draw_background(img)

    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2

    line_w = max(2, int(size * 0.08))
    white = (255, 255, 255, 255)

    # "A" legs
    left_bottom = (int(cx - size * 0.25), int(cy + size * 0.28))
    left_top    = (int(cx - size * 0.08), int(cy - size * 0.25))
    right_bottom= (int(cx + size * 0.25), int(cy + size * 0.28))
    right_top   = (int(cx + size * 0.08), int(cy - size * 0.25))
    _aa_line(draw, left_bottom, left_top, white, line_w)
    _aa_line(draw, right_bottom, right_top, white, line_w)

    # cross bar
    bar_y = int(cy + size * 0.05)
    bar_x0 = int(cx - size * 0.16)
    bar_x1 = int(cx + size * 0.16)
    _aa_line(draw, (bar_x0, bar_y), (bar_x1, bar_y), white, line_w)

    # nodes
    r = max(2, int(size * 0.04))
    nodes = [
        (cx, int(cy - size * 0.30)),
        (int(cx - size * 0.30), int(cy + size * 0.30)),
        (int(cx + size * 0.30), int(cy + size * 0.30)),
    ]
    for (nx, ny) in nodes:
        draw.ellipse([(nx - r, ny - r), (nx + r, ny + r)], fill=white)

    return img


# --------- IO ----------

DEFAULT_CONFIGS = [
    # Android
    (48,  "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"),
    (72,  "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"),
    (96,  "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"),
    (144, "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"),
    (192, "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"),
    # Web
    (192, "web/icons/Icon-192.png"),
    (512, "web/icons/Icon-512.png"),
    (192, "web/favicon.png"),
    # iOS base (App Store) — Xcode still manages full set
    (1024, "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"),
]


def save_png(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Ensure exact size by resampling only if needed
    # (our generator already makes target size)
    img.save(path, format="PNG", optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", type=str, default="", help="Optional base dir prefix (e.g., 'app')")
    args = ap.parse_args()

    base = Path(args.base) if args.base else None

    for size, rel in DEFAULT_CONFIGS:
        out_path = Path(rel)
        if base:
            out_path = base / out_path
        icon = create_icon(size)
        save_png(icon, out_path)
        print(f"✓ {out_path} ({size}x{size})")

    print("\n✓ All icons generated")


if __name__ == "__main__":
    main()
