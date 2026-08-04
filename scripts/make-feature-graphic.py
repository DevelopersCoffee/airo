#!/usr/bin/env python3
"""Render a 1024x500 store feature graphic for an Airo app.

Matches the existing Airo TV asset's visual language so the listings read as
one family. Copy is passed in rather than hardcoded, and deliberately carries
no performance, ranking, price, or promotional claims -- stores reject those,
and Airo's own README commits to not making them.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 1024, 500
BG = (10, 10, 10)
PANEL = (26, 26, 26)
ACCENT = (247, 224, 176)      # the cream Airo uses for primary surfaces
TEXT = (245, 245, 245)
MUTED = (150, 150, 150)

FONT_DIR = Path("/System/Library/Fonts/Supplemental")


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    for candidate in (FONT_DIR / name, Path("/Library/Fonts") / name):
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def render(title: str, subtitle: str, chips: list[str], note: str,
           rows: list[tuple[str, str]], icon: Path | None, out: Path) -> Path:
    image = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(image)

    title_font = font("Arial Black.ttf", 62)
    sub_font = font("Arial Bold.ttf", 26)
    chip_font = font("Arial Bold.ttf", 18)
    note_font = font("Arial.ttf", 18)
    row_font = font("Arial Bold.ttf", 22)
    row_sub_font = font("Arial.ttf", 17)

    x = 56
    y = 88
    if icon and icon.is_file():
        # LANCZOS: the source is 192x192, so a default-filter downscale to 72
        # visibly softens the strokes.
        badge = Image.open(icon).convert("RGBA").resize((72, 72), Image.LANCZOS)
        image.paste(badge, (x, y - 6), badge)
        x_text = x + 92
    else:
        x_text = x

    draw.text((x_text, y), title, font=title_font, fill=TEXT)
    draw.text((56, y + 92), subtitle, font=sub_font, fill=MUTED)

    cx = 56
    for chip in chips:
        w = draw.textlength(chip, font=chip_font)
        rounded(draw, (cx, 246, cx + w + 34, 292), 12, fill=PANEL, outline=(60, 60, 60))
        draw.text((cx + 17, 258), chip, font=chip_font, fill=TEXT)
        cx += w + 48

    for index, line in enumerate(note.split("\n")):
        draw.text((56, 344 + index * 26), line, font=note_font, fill=MUTED)

    # Right-hand mock panel: illustrative UI, never a real user's data.
    rounded(draw, (586, 56, 968, 444), 18, fill=(18, 18, 18), outline=(48, 48, 48))
    draw.text((620, 88), rows[0][0], font=font("Arial Bold.ttf", 28), fill=ACCENT)
    ry = 148
    for label, value in rows[1:]:
        rounded(draw, (620, ry, 934, ry + 74), 12, fill=PANEL)
        # Leading accent block: mirrors the app's own list rows.
        rounded(draw, (636, ry + 22, 660, ry + 52), 6, fill=ACCENT)
        draw.text((676, ry + 14), label, font=row_font, fill=TEXT)
        if 676 + draw.textlength(value, font=row_sub_font) > 934 - 12:
            raise ValueError(f"row subtitle overflows the panel: {value!r}")
        draw.text((676, ry + 44), value, font=row_sub_font, fill=MUTED)
        ry += 90

    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preset", choices=["airo", "coins"], required=True)
    parser.add_argument("--icon", type=Path, default=Path("app/assets/airo_icon.png"))
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    if args.preset == "airo":
        path = render(
            "Airo",
            "Local-first money, TV and more",
            # Only shipped capabilities. The README marks Airo AI as in
            # development, and a capability chip reads as a feature claim.
            ["IPTV player", "Money & splits", "Secure vault"],
            "Open source. No channels or media included.\nYour data stays on your device.",
            [("Today", ""), ("Quick add", "Type naturally, Airo drafts it"),
             ("Secure vault", "Unlocked with biometrics"),
             ("Live TV", "Bring your own playlist")],
            args.icon, args.out,
        )
    else:
        path = render(
            "Airo Coins",
            "Local-first money vault",
            ["Biometric lock", "Works offline", "No account"],
            "Records never leave your device.\nPreview release.",
            [("Your phone is the vault", ""),
             ("Bank accounts", "Unlocked with biometrics"),
             ("Cards & documents", "Stored on device"),
             ("Spending", "Tracked locally only")],
            args.icon, args.out,
        )
    print(f"wrote {path} ({Image.open(path).size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
