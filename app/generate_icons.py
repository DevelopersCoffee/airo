#!/usr/bin/env python3
"""
Generate app icons from SVG for all platforms.
Requires: pip install cairosvg
Fallbacks: ImageMagick ('magick' or 'convert') or rsvg-convert
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path

SVG_FILE = "assets/airo_icon.svg"

ICON_CONFIGS = [
    # Android
    ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
    ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
    ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
    ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
    ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
    # Web
    ("web/icons/Icon-192.png", 192),
    ("web/icons/Icon-512.png", 512),
    ("web/favicon.png", 192),
    # iOS base icon
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", 1024),
]


def find_svg_backend():
    """Return a callable that converts (svg_path, out_path, size) or None if no backend."""
    try:
        import cairosvg  # type: ignore

        def cairosvg_backend(svg_path, out_path, size):
            cairosvg.svg2png(url=svg_path, write_to=out_path, output_width=size, output_height=size)

        return cairosvg_backend
    except Exception:
        pass

    # Prefer 'magick' (ImageMagick 7+), else 'convert'
    magick_cmd = shutil.which("magick") or shutil.which("convert")
    if magick_cmd:
        def magick_backend(svg_path, out_path, size):
            # Use magick/convert to rasterize. '-background none' keeps alpha.
            subprocess.run([
                magick_cmd,
                svg_path,
                "-background", "none",
                "-resize", f"{size}x{size}",
                out_path
            ], check=True)
        return magick_backend

    # Try rsvg-convert
    rsvg = shutil.which("rsvg-convert")
    if rsvg:
        def rsvg_backend(svg_path, out_path, size):
            subprocess.run([rsvg, "-w", str(size), "-h", str(size), "-o", out_path, svg_path], check=True)
        return rsvg_backend

    return None


def generate_icons(svg_file=SVG_FILE, icon_configs=ICON_CONFIGS):
    svg_path = Path(svg_file)
    if not svg_path.is_file():
        print(f"Error: SVG not found: {svg_file}", file=sys.stderr)
        return False

    backend = find_svg_backend()
    if backend is None:
        print("Error: No SVG backend found. Install 'cairosvg' or ImageMagick or rsvg-convert.", file=sys.stderr)
        return False

    failures = []
    print("Generating icons from SVG...")

    for out_rel, size in icon_configs:
        out_path = Path(out_rel)
        out_path.parent.mkdir(parents=True, exist_ok=True)

        try:
            # Use chosen backend
            backend(str(svg_path), str(out_path), int(size))
            # Verify file created and non-empty
            if not out_path.is_file() or out_path.stat().st_size == 0:
                raise RuntimeError("Output file missing or empty")
            print(f"✓ {out_path} ({size}x{size})")
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to generate {out_path}: subprocess error ({e})", file=sys.stderr)
            failures.append(out_path)
        except Exception as e:
            print(f"✗ Failed to generate {out_path}: {e}", file=sys.stderr)
            failures.append(out_path)

    if failures:
        print(f"\n✗ {len(failures)} icons failed.", file=sys.stderr)
        return False

    print("\n✓ All icons generated successfully!")
    return True


if __name__ == "__main__":
    ok = generate_icons()
    sys.exit(0 if ok else 1)
