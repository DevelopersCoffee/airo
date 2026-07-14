#!/usr/bin/env python3
"""Generate Airo TV store-listing PNG assets.

The images are deterministic release assets for store submissions. They use
demo playlist/channel data only and do not include private playlist URLs,
tokens, serial numbers, or account details.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:  # pragma: no cover - local tooling guard.
    raise SystemExit(
        "Pillow is required to generate store assets. "
        "Install it with `python3 -m pip install Pillow`."
    ) from exc


CHANNELS = [
    ("City News Live", "News", "LIVE", "teal"),
    ("Stadium Sports HD", "Sports", "HD", "yellow"),
    ("Music Pulse", "Music", "AUDIO", "blue"),
    ("World Docs", "Documentary", "DOC", "purple"),
    ("Market Watch", "Business", "LIVE", "rose"),
    ("Family Cinema", "Movies", "HD", "green"),
]

COLORS = {
    "bg": "#0F172A",
    "bg2": "#111827",
    "panel": "#172033",
    "panel2": "#1E293B",
    "line": "#334155",
    "line2": "#475569",
    "text": "#FFFFFF",
    "muted": "#CBD5E1",
    "soft": "#94A3B8",
    "teal": "#2DD4BF",
    "yellow": "#F8C14A",
    "blue": "#93C5FD",
    "purple": "#A78BFA",
    "rose": "#FB7185",
    "green": "#34D399",
    "red": "#EF4444",
}

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/Library/Fonts/Arial.ttf",
]


def main() -> None:
    out = store_asset_directory()
    out.mkdir(parents=True, exist_ok=True)

    draw_browse().save(out / "01-tv-home-channel-grid.png")
    draw_now_playing().save(out / "02-tv-now-playing.png")
    draw_search().save(out / "03-tv-search-dialog.png")
    draw_playlist().save(out / "04-tv-playlist-source.png")
    draw_feature_graphic().save(out / "feature-graphic-1024x500.png")

    for asset in sorted(out.glob("*.png")):
        print(asset.relative_to(repo_root()))


def repo_root() -> Path:
    configured = os.environ.get("AIRO_REPO_ROOT")
    if configured:
        return Path(configured).expanduser().resolve()
    return Path(__file__).resolve().parents[3]


def store_asset_directory() -> Path:
    return repo_root() / "docs" / "store-assets" / "airo-tv"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for candidate in candidates + FONT_CANDIDATES:
        if candidate and Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default()


def canvas(size: tuple[int, int], fill: str = "bg") -> Image.Image:
    return Image.new("RGB", size, COLORS[fill])


def draw_shell(title: str, subtitle: str) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = canvas((1920, 1080))
    draw = ImageDraw.Draw(image)
    draw.text((118, 68), "AIRO TV", fill=COLORS["text"], font=font(46, True))
    pill(draw, (1605, 74, 1810, 122), "BYO playlist", "panel2", "line2")
    draw.text((112, 158), title, fill=COLORS["text"], font=font(56, True))
    draw.text((114, 226), subtitle, fill=COLORS["muted"], font=font(26))
    return image, draw


def draw_browse() -> Image.Image:
    image, draw = draw_shell(
        "Browse authorized playlists",
        "TV-first channel grid for M3U and M3U8 sources.",
    )

    x, y = 112, 320
    for idx, label in enumerate(
        ["All channels", "News", "Sports", "Music", "Documentary", "Movies"]
    ):
        selected = idx == 0
        rect = (x, y + idx * 92, x + 330, y + idx * 92 + 68)
        rounded(draw, rect, "panel2" if selected else "bg2", "teal" if selected else "line")
        draw.text((rect[0] + 28, rect[1] + 19), label, fill=COLORS["text"], font=font(24, True))

    start_x, start_y = 486, 320
    card_w, card_h = 390, 210
    for idx, channel in enumerate(CHANNELS):
        col = idx % 3
        row = idx // 3
        x = start_x + col * (card_w + 26)
        y = start_y + row * (card_h + 26)
        draw_channel_card(draw, (x, y, x + card_w, y + card_h), channel, selected=idx == 0)
    return image


def draw_now_playing() -> Image.Image:
    image, draw = draw_shell(
        "Now playing on TV",
        "Large controls, clear metadata, and quick return to channels.",
    )

    video = (112, 318, 1245, 936)
    rounded(draw, video, "bg2", "line")
    draw.rectangle((video[0] + 1, video[1] + 1, video[2] - 1, video[3] - 1), fill="#020617")
    draw.ellipse((610, 520, 746, 656), fill=COLORS["text"])
    draw.polygon([(662, 553), (662, 623), (720, 588)], fill=COLORS["teal"])
    draw.ellipse((152, 880, 172, 900), fill=COLORS["red"])
    draw.text((188, 870), "Live channel", fill=COLORS["text"], font=font(28, True))

    panel = (1282, 318, 1808, 936)
    rounded(draw, panel, "panel", "line")
    draw.text((1322, 360), "City News Live", fill=COLORS["text"], font=font(48, True))
    draw.text((1324, 424), "News", fill=COLORS["muted"], font=font(26, True))
    pill(draw, (1324, 478, 1446, 526), "Full HD", "bg2", "line2")
    pill(draw, (1462, 478, 1560, 526), "Live", "bg2", "line2")
    pill(draw, (1576, 478, 1668, 526), "Cast", "bg2", "line2")
    draw.text((1324, 596), "Recently watched", fill=COLORS["text"], font=font(30, True))
    for idx, channel in enumerate(CHANNELS[:3]):
        draw_feature_tile(draw, (1324, 648 + idx * 86, 1768, 714 + idx * 86), channel, selected=idx == 0)
    return image


def draw_search() -> Image.Image:
    image, draw = draw_shell(
        "Find channels fast",
        "Search across your authorized playlist on Android TV.",
    )

    panel = (380, 300, 1540, 930)
    rounded(draw, panel, "panel", "line")
    draw.text((430, 354), "Search channels", fill=COLORS["text"], font=font(44, True))
    search = (430, 438, 1490, 506)
    rounded(draw, search, "bg2", "blue", width=2)
    draw.text((464, 456), "sports", fill=COLORS["text"], font=font(30, True))
    draw.text((430, 550), "Results", fill=COLORS["muted"], font=font(24, True))
    draw_feature_tile(draw, (430, 594, 1490, 676), CHANNELS[1], selected=True)
    draw_feature_tile(draw, (430, 696, 1490, 778), CHANNELS[0])
    return image


def draw_playlist() -> Image.Image:
    image, draw = draw_shell(
        "Use your own playlist",
        "Airo TV does not include channels or media subscriptions.",
    )

    left = (112, 318, 920, 934)
    rounded(draw, left, "panel", "line")
    steps = [
        ("1", "Add an authorized M3U or M3U8 URL", "Use playlist sources you have permission to access."),
        ("2", "Browse channels on the TV grid", "Categories and search help keep large playlists usable."),
        ("3", "Play on Android TV", "Designed for remote navigation and living room screens."),
    ]
    y = 376
    for number, title, body in steps:
        rounded(draw, (164, y, 220, y + 56), "panel2", "teal")
        draw.text((182, y + 12), number, fill=COLORS["teal"], font=font(26, True))
        draw.text((248, y), title, fill=COLORS["text"], font=font(28, True))
        wrapped(draw, body, (250, y + 42), 580, font(21), COLORS["muted"])
        y += 150

    right = (972, 318, 1808, 934)
    rounded(draw, right, "bg2", "line")
    draw.text((1028, 404), "Playlist source", fill=COLORS["text"], font=font(42, True))
    url = (1028, 488, 1752, 562)
    rounded(draw, url, "bg", "line2")
    draw.text(
        (1052, 512),
        "https://demo.airo.app/playlists/authorized-tv-demo.m3u",
        fill=COLORS["text"],
        font=font(23, True),
    )
    pill(draw, (1028, 626, 1158, 676), "M3U/M3U8", "panel", "line2")
    pill(draw, (1178, 626, 1328, 676), "BYO source", "panel", "line2")
    pill(draw, (1348, 626, 1468, 676), "TV layout", "panel", "line2")
    return image


def draw_feature_graphic() -> Image.Image:
    image = canvas((1024, 500), "bg2")
    draw = ImageDraw.Draw(image)
    draw.text((52, 86), "Airo TV", fill=COLORS["text"], font=font(74, True))
    draw.text((56, 176), "IPTV playlist player for Android TV", fill=COLORS["muted"], font=font(30, True))
    pill(draw, (56, 252, 174, 300), "M3U/M3U8", "panel", "line2")
    pill(draw, (192, 252, 296, 300), "Search", "panel", "line2")
    pill(draw, (314, 252, 396, 300), "Cast", "panel", "line2")
    wrapped(
        draw,
        "Bring your own authorized playlists. No channels included.",
        (56, 344),
        460,
        font(21),
        COLORS["muted"],
    )
    panel = (585, 58, 970, 442)
    rounded(draw, panel, "panel", "line")
    draw.text((620, 94), "Live channels", fill=COLORS["text"], font=font(31, True))
    for idx, channel in enumerate(CHANNELS[:3]):
        draw_feature_tile(draw, (620, 154 + idx * 86, 930, 218 + idx * 86), channel, selected=idx == 0)
    return image


def draw_channel_card(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    channel: tuple[str, str, str, str],
    selected: bool = False,
) -> None:
    name, group, badge, color = channel
    rounded(draw, rect, "panel2" if selected else "bg2", color if selected else "line", width=2 if selected else 1)
    chip = (rect[0] + 26, rect[1] + 26, rect[0] + 112, rect[1] + 76)
    rounded(draw, chip, "panel", color)
    draw.text((chip[0] + 16, chip[1] + 13), badge, fill=COLORS[color], font=font(17, True))
    draw.text((rect[0] + 26, rect[3] - 74), name, fill=COLORS["text"], font=font(30, True))
    draw.text((rect[0] + 26, rect[3] - 36), group, fill=COLORS["muted"], font=font(20, True))


def draw_feature_tile(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    channel: tuple[str, str, str, str],
    selected: bool = False,
) -> None:
    name, group, _badge, color = channel
    rounded(draw, rect, "panel2" if selected else "bg2", color if selected else "line")
    draw.rectangle((rect[0] + 18, rect[1] + 16, rect[0] + 50, rect[1] + 50), fill=COLORS[color])
    draw.text((rect[0] + 70, rect[1] + 12), name, fill=COLORS["text"], font=font(23, True))
    draw.text((rect[0] + 70, rect[1] + 42), group, fill=COLORS["muted"], font=font(17))


def pill(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    label: str,
    fill: str,
    outline: str,
    width: int = 1,
) -> None:
    rounded(draw, rect, fill, outline, width=width)
    text_width = draw.textlength(label, font=font(18, True))
    draw.text(
        (rect[0] + (rect[2] - rect[0] - text_width) / 2, rect[1] + 13),
        label,
        fill=COLORS["text"],
        font=font(18, True),
    )


def rounded(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    fill: str,
    outline: str,
    radius: int = 8,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(
        rect,
        radius=radius,
        fill=COLORS[fill],
        outline=COLORS[outline],
        width=width,
    )


def wrapped(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    max_width: int,
    text_font: ImageFont.ImageFont,
    fill: str,
    line_height: int = 30,
) -> None:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=text_font) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    for idx, line in enumerate(lines):
        draw.text((xy[0], xy[1] + idx * line_height), line, fill=fill, font=text_font)


if __name__ == "__main__":
    main()
