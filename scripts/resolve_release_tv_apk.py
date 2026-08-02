#!/usr/bin/env python3
"""Resolve the canonical Airo TV APK from a GitHub release asset list."""

from __future__ import annotations

import json
import re
import sys
from collections.abc import Iterable


CANONICAL_TV_APK = re.compile(r"^Airo-TV-.+\.apk$")
ABI_SPLIT_APK = re.compile(r"-(?:arm64-v8a|armeabi-v7a|x86_64)\.apk$")


def resolve_canonical_tv_apk(asset_names: Iterable[str]) -> str:
    candidates = sorted(
        name
        for name in asset_names
        if CANONICAL_TV_APK.fullmatch(name) and not ABI_SPLIT_APK.search(name)
    )
    if len(candidates) != 1:
        rendered = ", ".join(candidates) if candidates else "none"
        raise ValueError(
            "expected exactly one canonical Airo TV APK release asset; "
            f"found {len(candidates)} ({rendered})"
        )
    return candidates[0]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        assets = payload.get("assets", [])
        names = [asset["name"] for asset in assets if isinstance(asset, dict)]
        print(resolve_canonical_tv_apk(names))
    except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        print(f"::error::{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
