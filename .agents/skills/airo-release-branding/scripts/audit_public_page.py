#!/usr/bin/env python3
"""Audit the split Airo platform and Airo TV public pages."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse


class Inventory(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()
        self.links: list[str] = []
        self.sources: list[str] = []
        self.autoplay_videos = 0
        self.live_demo_roots = 0
        self.live_demo_videos = 0
        self.muted_live_demo_videos = 0
        self.preloading_live_demo_videos = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if values.get("id"):
            self.ids.add(values["id"] or "")
        if values.get("href"):
            self.links.append(values["href"] or "")
        if values.get("src"):
            self.sources.append(values["src"] or "")
        if "data-live-demo" in values:
            self.live_demo_roots += 1
        if tag == "video" and "autoplay" in values:
            self.autoplay_videos += 1
        if tag == "video" and "data-live-demo-video" in values:
            self.live_demo_videos += 1
            if "muted" in values:
                self.muted_live_demo_videos += 1
            if values.get("preload") != "none":
                self.preloading_live_demo_videos += 1


def latest_public_tv_release(repository: str) -> str:
    command = [
        "gh",
        "release",
        "list",
        "--repo",
        repository,
        "--limit",
        "50",
        "--json",
        "tagName,isDraft,isPrerelease,publishedAt",
    ]
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
    except (FileNotFoundError, subprocess.CalledProcessError) as error:
        detail = getattr(error, "stderr", "") or str(error)
        raise RuntimeError(f"GitHub release lookup failed: {detail.strip()}") from error
    for release in json.loads(result.stdout):
        tag = release.get("tagName", "")
        if (
            tag.startswith("airo-tv-v")
            and "-rc." not in tag
            and not release.get("isDraft")
            and not release.get("isPrerelease")
        ):
            return tag
    raise RuntimeError("No published, non-release-candidate Airo TV release found")


def local_target(base: Path, raw: str) -> Path | None:
    parsed = urlparse(raw)
    if parsed.scheme or parsed.netloc or raw.startswith(("#", "mailto:")):
        return None
    path = unquote(parsed.path)
    return (base / path).resolve() if path else None


def inspect_html(path: Path) -> tuple[str, Inventory]:
    text = path.read_text(encoding="utf-8")
    inventory = Inventory()
    inventory.feed(text)
    return text, inventory


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--repository", default="DevelopersCoffee/airo")
    parser.add_argument("--release-tag", help="Override GitHub lookup for offline checks")
    args = parser.parse_args()

    root = args.root.resolve()
    platform_page = root / "docs" / "index.html"
    tv_page = root / "docs" / "tv" / "index.html"
    legacy_guides = root / "docs" / "airo-tv" / "guides" / "index.html"
    tv_guides = root / "docs" / "tv" / "guides" / "index.html"
    site_script = root / "docs" / "assets" / "airo-tv" / "site.js"
    site_styles = root / "docs" / "assets" / "airo-tv" / "site.css"
    required_files = (platform_page, tv_page, legacy_guides, tv_guides, site_script, site_styles)
    errors = [f"missing required file: {path.relative_to(root)}" for path in required_files if not path.is_file()]
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    release_tag = args.release_tag or latest_public_tv_release(args.repository)
    platform_text, platform = inspect_html(platform_page)
    tv_text, tv = inspect_html(tv_page)
    legacy_text, legacy = inspect_html(legacy_guides)
    tv_guides_text, tv_guide = inspect_html(tv_guides)
    script_text = site_script.read_text(encoding="utf-8")
    styles_text = site_styles.read_text(encoding="utf-8")

    required_platform_sections = {"architecture", "foundations", "modules", "community", "roadmap", "tv-reference", "trust"}
    missing_platform_sections = sorted(required_platform_sections - platform.ids)
    if missing_platform_sections:
        errors.append("missing platform page sections: " + ", ".join(missing_platform_sections))

    required_tv_sections = {"product", "browse", "difference", "devices", "capability-matrix", "guides", "community", "pro-vision", "roadmap", "trust"}
    missing_tv_sections = sorted(required_tv_sections - tv.ids)
    if missing_tv_sections:
        errors.append("missing Airo TV page sections: " + ", ".join(missing_tv_sections))

    required_guides = {"android-tv", "fire-tv", "mobile", "cast", "macos", "playlist", "troubleshooting"}
    missing_guides = sorted(required_guides - legacy.ids)
    if missing_guides:
        errors.append("missing legacy device guides: " + ", ".join(missing_guides))

    platform_snippets = {
        '<h1 id="hero-title">Airo</h1>': "Airo platform hero identity",
        "Airo TV is available": "active module status",
        "./tv/": "Airo TV product hand-off",
        "Airo TV Pro": "advanced TV edition name",
        "Exploring": "future module qualifier",
    }
    tv_snippets = {
        release_tag: "published Airo TV release tag",
        '<h1 id="hero-title">Airo TV</h1>': "Airo TV product hero identity",
        "Airo TV includes no channels": "application content boundary",
        "Make your own playlist feel smaller.": "browse-and-organization product story",
        "Saved browse views": "planned saved-view disclosure",
        'data-live-channel="Vevo Pop"': "approved hero preview identity",
        "d128y56w6v2kax.cloudfront.net": "approved direct HLS source",
        "Third-party stream details": "third-party stream disclosure",
        "Start muted preview": "manual preview fallback",
        "community-voice": "Community Voice link",
        "/milestone/5": "product milestone link",
        "/milestone/6": "performance milestone link",
        "Airo TV Pro": "advanced TV edition name",
        "In testing": "unreleased Pro status",
        "unsigned and not notarized": "macOS limitation",
        "Deferred for the current v2 release wave": "iOS limitation",
        "validation-only": "web limitation",
    }
    guide_snippets = {
        "../../airo-tv/guides/#android-tv": "Android TV guide hand-off",
        "../../airo-tv/guides/#troubleshooting": "troubleshooting guide hand-off",
    }
    for snippets, text in ((platform_snippets, platform_text), (tv_snippets, tv_text), (guide_snippets, tv_guides_text)):
        for snippet, label in snippets.items():
            if snippet not in text:
                errors.append(f"missing {label}: {snippet}")

    required_scroll_logic = {
        "IntersectionObserver": "one-time viewport reveal",
        "revealObserver.unobserve": "completed reveal cleanup",
        "requestAnimationFrame": "composited progress scheduling",
        "prefers-reduced-motion: reduce": "motion preference detection",
    }
    for snippet, label in required_scroll_logic.items():
        if snippet not in script_text:
            errors.append(f"missing {label}: {snippet}")

    required_preview_logic = {
        'querySelectorAll("[data-live-demo]")': "preview initialization",
        '"liveAutoplayMuted" in root.dataset': "muted preview contract",
        "entry.intersectionRatio >= 0.35": "preview visibility threshold",
        "autoplayBlockedByInitialHash": "non-hero deep-link guard",
        "demoVideo.muted = true": "forced muted preview",
        "demoAudio.addEventListener": "user-controlled audio toggle",
        "demoHls.stopLoad()": "off-screen network pause",
        "reducedMotion": "reduced-motion preview guard",
        "demoRecoveryAttempts >= 1": "bounded preview recovery",
    }
    for snippet, label in required_preview_logic.items():
        if snippet not in script_text:
            errors.append(f"missing {label}: {snippet}")

    required_visual_styles = {
        "--section-space": "shared section rhythm token",
        "text-wrap: balance": "balanced heading treatment",
        'aria-current="location"': "active section navigation treatment",
        "min-height: 44px": "minimum interactive target rule",
        ".platform-hero": "platform visual treatment",
        ".foundation-grid": "platform foundations layout",
        ".module-groups": "module map layout",
        "@media (prefers-reduced-motion: reduce)": "reduced motion style",
    }
    for snippet, label in required_visual_styles.items():
        if snippet not in styles_text + script_text:
            errors.append(f"missing {label}: {snippet}")

    forbidden = {
        "github.com/DevelopersCoffee/airo-pro": "private repository URL",
        "packages_pro/": "private package path",
        "TMDB_API_KEY": "private integration detail",
        "cdn.airo.tv": "private service host",
        "Launch Web App": "unsupported web CTA",
        "View App Store": "unsupported iOS CTA",
        "Airo Pro": "retired Pro product name",
        "Airo Mind": "unsupported Airo sub-brand",
        "Airo Money": "unsupported Airo sub-brand",
        "Airo Life": "unsupported Airo sub-brand",
        "Airo Play": "unsupported Airo sub-brand",
    }
    all_public_text = platform_text + tv_text + legacy_text + tv_guides_text
    for snippet, label in forbidden.items():
        if snippet in all_public_text:
            errors.append(f"forbidden {label}: {snippet}")

    for page_name, inventory in (("platform", platform), ("Airo TV", tv)):
        if inventory.autoplay_videos:
            errors.append(f"{page_name} page video must not use autoplay")

    if platform.live_demo_roots:
        errors.append("platform page must not contain a live-demo root")
    if tv.live_demo_roots != 1:
        errors.append("Airo TV page must contain exactly one hero preview root")
    if tv.live_demo_videos != 1:
        errors.append("Airo TV page must contain exactly one hero preview video")
    if tv.muted_live_demo_videos != 1:
        errors.append("Airo TV hero preview must begin muted")
    if tv.preloading_live_demo_videos:
        errors.append("Airo TV hero preview must use preload=none")

    for html_path, inventory in ((platform_page, platform), (tv_page, tv), (legacy_guides, legacy), (tv_guides, tv_guide)):
        for raw in inventory.sources:
            target = local_target(html_path.parent, raw)
            if target is not None and not target.exists():
                errors.append(f"missing local asset from {html_path.relative_to(root)}: {raw}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAIL: {len(errors)} release-branding issue(s)")
        return 1

    source_count = len(platform.sources) + len(tv.sources) + len(legacy.sources) + len(tv_guide.sources)
    print(f"PASS: split public pages match release-branding contract for {release_tag}")
    print(f"PASS: {source_count} public-page assets resolve locally")
    print(f"PASS: {len(required_guides)} legacy device guides and the /tv/guides hub are present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
