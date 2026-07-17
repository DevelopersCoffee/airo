#!/usr/bin/env python3
"""Audit the Airo public page against the release-branding contract."""

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
        self.muted_autoplay_live_demo_roots = 0
        self.live_demo_videos = 0
        self.live_sample_videos = 0
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
        if "data-live-autoplay-muted" in values:
            self.muted_autoplay_live_demo_roots += 1
        if tag == "video" and "autoplay" in values:
            self.autoplay_videos += 1
        if tag == "video" and "data-live-demo-video" in values:
            self.live_demo_videos += 1
            if "live-sample-video" in (values.get("class") or "").split():
                self.live_sample_videos += 1
            if "muted" in values:
                self.muted_live_demo_videos += 1
            if values.get("preload") != "none":
                self.preloading_live_demo_videos += 1


def latest_tv_release(repository: str) -> str:
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
    releases = json.loads(result.stdout)
    for release in releases:
        tag = release.get("tagName", "")
        if tag.startswith("airo-tv-v") and not release.get("isDraft"):
            return tag
    raise RuntimeError("No published Airo TV release found")


def local_target(base: Path, raw: str) -> Path | None:
    parsed = urlparse(raw)
    if parsed.scheme or parsed.netloc or raw.startswith(("#", "mailto:")):
        return None
    path = unquote(parsed.path)
    if not path:
        return None
    return (base / path).resolve()


def inspect_html(path: Path) -> tuple[str, Inventory]:
    text = path.read_text(encoding="utf-8")
    parser = Inventory()
    parser.feed(text)
    return text, parser


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--repository", default="DevelopersCoffee/airo")
    parser.add_argument("--release-tag", help="Override GitHub lookup for offline checks")
    args = parser.parse_args()

    root = args.root.resolve()
    index = root / "docs" / "index.html"
    guides = root / "docs" / "airo-tv" / "guides" / "index.html"
    site_script = root / "docs" / "assets" / "airo-tv" / "site.js"
    site_styles = root / "docs" / "assets" / "airo-tv" / "site.css"
    errors: list[str] = []

    for required in (index, guides, site_script, site_styles):
        if not required.is_file():
            errors.append(f"missing required file: {required.relative_to(root)}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    release_tag = args.release_tag or latest_tv_release(args.repository)
    index_text, index_inventory = inspect_html(index)
    guide_text, guide_inventory = inspect_html(guides)
    site_script_text = site_script.read_text(encoding="utf-8")
    site_styles_text = site_styles.read_text(encoding="utf-8")

    required_sections = {
        "product",
        "difference",
        "live-demo",
        "devices",
        "guides",
        "community",
        "pro-vision",
        "roadmap",
        "airo",
        "trust",
    }
    missing_sections = sorted(required_sections - index_inventory.ids)
    if missing_sections:
        errors.append("missing page sections: " + ", ".join(missing_sections))

    required_guides = {
        "android-tv",
        "fire-tv",
        "mobile",
        "cast",
        "macos",
        "playlist",
        "troubleshooting",
    }
    missing_guides = sorted(required_guides - guide_inventory.ids)
    if missing_guides:
        errors.append("missing device guides: " + ", ".join(missing_guides))

    required_snippets = {
        release_tag: "latest release tag",
        "community-voice": "Community Voice link",
        "/milestone/5": "product milestone link",
        "/milestone/6": "performance milestone link",
        "Airo TV app includes no channels": "application content boundary",
        '<h1 id="hero-title">Airo</h1>': "default Airo hero identity",
        "Airo TV available now": "current focused product status",
        "Airo TV Pro": "advanced TV edition name",
        "In testing": "unreleased Pro status",
        "Airo is the home": "superapp parent positioning",
        "Nothing loads until you press Play": "user-initiated demo boundary",
        "Third-party stream": "external stream status",
        "github.com/iptv-org/iptv": "public source attribution",
        "cdn-uw2-prod.tsv2.amagi.tv": "approved live demo source",
        "Vevo Pop": "immersive live showcase name",
        "d128y56w6v2kax.cloudfront.net": "approved Vevo Pop showcase source",
        "Start muted preview": "manual autoplay fallback",
        "Muted preview starts on screen.": "visibility-gated preview status",
        ">Unmute</span>": "explicit audio control",
        "Third-party stream details": "compact stream disclosure",
        "live-demo-player-status": "secondary player overlay status",
        "live-demo-disclosure": "secondary compact disclosure",
        "HLS.js Apache license": "player dependency attribution",
    }
    for snippet, label in required_snippets.items():
        if snippet not in index_text:
            errors.append(f"missing {label}: {snippet}")

    required_demo_logic = {
        'querySelectorAll("[data-live-demo]")': "shared multi-sample initialization",
        "Retrying live stream automatically": "automatic recovery status",
        "recoverMediaError": "HLS media recovery",
        "demoRecoveryAttempts >= 1": "bounded recovery attempt",
        "8000": "recovery deadline",
        "airo_retry=": "native HLS cache-busted retry",
        'root.hasAttribute("data-live-autoplay-muted")': "muted autoplay contract",
        "entry.intersectionRatio >= 0.35": "visibility threshold",
        "observeMutedPreview": "deep-link-safe observer setup",
        "autoplayBlockedByInitialHash": "non-showcase deep-link guard",
        "demoVideo.muted = true": "forced muted autoplay",
        "demoAudio.addEventListener": "user-controlled audio toggle",
        "demoHls.stopLoad()": "off-screen network pause",
        "instance.isActive()": "manual playback precedence",
    }
    for snippet, label in required_demo_logic.items():
        if snippet not in site_script_text:
            errors.append(f"missing {label}: {snippet}")

    required_scroll_logic = {
        "IntersectionObserver": "one-time viewport reveal",
        "revealObserver.unobserve": "completed reveal cleanup",
        "requestAnimationFrame": "composited progress scheduling",
        "prefers-reduced-motion: reduce": "motion preference detection",
    }
    for snippet, label in required_scroll_logic.items():
        if snippet not in site_script_text:
            errors.append(f"missing {label}: {snippet}")

    required_scroll_styles = {
        ".scroll-progress": "scroll progress style",
        ".scroll-reveal.is-visible": "visible reveal state",
        "@media (prefers-reduced-motion: reduce)": "reduced motion style",
    }
    for snippet, label in required_scroll_styles.items():
        if snippet not in site_styles_text:
            errors.append(f"missing {label}: {snippet}")

    required_visual_styles = {
        "--section-space": "shared section rhythm token",
        "text-wrap: balance": "balanced heading treatment",
        ".screen-step:nth-child(even)": "alternating media proportion rule",
        'aria-current="location"': "active section navigation treatment",
        "min-height: 44px": "minimum interactive target rule",
        ".live-sample-video": "shared live media geometry",
        ".live-demo-player-status": "secondary overlay status alignment",
        "aspect-ratio: 16 / 9": "secondary live media ratio",
    }
    visual_contract_text = site_styles_text + site_script_text
    for snippet, label in required_visual_styles.items():
        if snippet not in visual_contract_text:
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
    combined = index_text + guide_text
    for snippet, label in forbidden.items():
        if snippet in combined:
            errors.append(f"forbidden {label}: {snippet}")

    if index_inventory.autoplay_videos:
        errors.append("live demo video must not use autoplay")
    if index_inventory.live_demo_roots != 2:
        errors.append("public page must expose exactly two live demo roots")
    if index_inventory.live_demo_videos != 2:
        errors.append("public page must expose exactly two live demo videos")
    if index_inventory.live_sample_videos != 2:
        errors.append("both live demo videos must use the shared media geometry")
    if index_inventory.muted_autoplay_live_demo_roots != 1:
        errors.append("exactly one immersive showcase must declare muted autoplay")
    if index_inventory.muted_live_demo_videos != 1:
        errors.append("exactly one immersive live showcase must declare muted playback")
    if index_inventory.preloading_live_demo_videos:
        errors.append("every live demo video must use preload=none")

    product_position = index_text.find('id="product"')
    showcase_position = index_text.find('id="vevo-showcase"')
    difference_position = index_text.find('id="difference"')
    if min(product_position, showcase_position, difference_position) < 0 or not (
        product_position < showcase_position < difference_position
    ):
        errors.append("immersive showcase must follow the release proof strip")

    hls_license = (
        root
        / "docs"
        / "assets"
        / "airo-tv"
        / "third-party"
        / "hls.js-1.6.16"
        / "LICENSE.txt"
    )
    if not hls_license.is_file():
        errors.append("missing vendored HLS.js license")

    for html_path, inventory in ((index, index_inventory), (guides, guide_inventory)):
        for raw in inventory.sources:
            target = local_target(html_path.parent, raw)
            if target is not None and not target.exists():
                errors.append(
                    f"missing local asset from {html_path.relative_to(root)}: {raw}"
                )

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        print(f"FAIL: {len(errors)} release-branding issue(s)")
        return 1

    print(f"PASS: public page matches release-branding contract for {release_tag}")
    print(f"PASS: {len(index_inventory.sources)} landing assets resolve locally")
    print(f"PASS: {len(required_guides)} required device guides are present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
