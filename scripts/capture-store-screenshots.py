#!/usr/bin/env python3
"""Capture phone store screenshots from a running Airo web build.

Attaches to a Chrome you signed in to yourself, over CDP, and captures the
screens you navigate to. It does not authenticate: Airo's web entrypoint gates
on sign-in, and this tool does not enter credentials -- not even the app's own
demo ones. A human signs in, then this captures.

    cd app && flutter build web --release --target=lib/main.dart \
        --dart-define=APP_VARIANT=full --dart-define=APP_PLATFORM=webFull
    (cd app/build/web && python3 -m http.server 8791) &
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
        --remote-debugging-port=9333 --user-data-dir=/tmp/airo-shots \
        http://127.0.0.1:8791/
    # sign in, navigate to the screen you want, then:
    python3 scripts/capture-store-screenshots.py --name home
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "artifacts" / "store-listing" / "raw"
PHONE_VIEWPORT = {"width": 390, "height": 844}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True, help="Screenshot name, e.g. home")
    parser.add_argument("--endpoint", default="http://127.0.0.1:9333")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--scale", type=int, default=2, help="Device pixel ratio")
    args = parser.parse_args()

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("playwright is not installed: python3 -m pip install playwright", file=sys.stderr)
        return 1

    args.out.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        try:
            browser = pw.chromium.connect_over_cdp(args.endpoint)
        except Exception as exc:  # noqa: BLE001
            print(f"Could not attach to Chrome at {args.endpoint}: {exc}", file=sys.stderr)
            return 2
        context = browser.contexts[0]
        page = next((p for p in context.pages if "127.0.0.1" in p.url), None)
        if page is None:
            print("No page serving the web build is open.", file=sys.stderr)
            return 3
        page.set_viewport_size(PHONE_VIEWPORT)
        page.wait_for_timeout(1500)
        target = args.out / f"airo-phone-{args.name}.png"
        page.screenshot(path=str(target), animations="disabled")
        print(f"wrote {target} ({target.stat().st_size} bytes) from {page.url}")
        browser.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
