#!/usr/bin/env python3
"""Bump a Flutter pubspec version using semantic version rules."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

VERSION_RE = re.compile(r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)\+(?P<build>\d+)$")


def parse_version(version: str) -> tuple[int, int, int, int]:
    match = VERSION_RE.fullmatch(version.strip())
    if not match:
        raise ValueError(f"Unsupported pubspec version format: {version}")
    return tuple(int(match.group(part)) for part in ("major", "minor", "patch", "build"))


def bump_version(version: str, release_type: str) -> str:
    major, minor, patch, build = parse_version(version)
    if release_type == "major":
        major += 1
        minor = 0
        patch = 0
    elif release_type == "minor":
        minor += 1
        patch = 0
    elif release_type == "patch":
        patch += 1
    else:
        raise ValueError(f"Unsupported release type: {release_type}")
    build += 1
    return f"{major}.{minor}.{patch}+{build}"


def validate_pubspec_path(pubspec_path: Path, repo_root: Path | None = None) -> Path:
    root = (repo_root or Path.cwd()).resolve()
    resolved_path = pubspec_path.resolve()

    if resolved_path.name != "pubspec.yaml":
        raise ValueError("Version bump target must be a pubspec.yaml file")

    if resolved_path == root or root not in resolved_path.parents:
        raise ValueError(f"Version bump target must be inside {root}")

    return resolved_path


def update_pubspec(pubspec_path: Path, release_type: str, repo_root: Path | None = None) -> str:
    safe_pubspec_path = validate_pubspec_path(pubspec_path, repo_root)
    text = safe_pubspec_path.read_text()
    match = re.search(r"^version:\s*(\S+)\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"Could not find version in {safe_pubspec_path}")

    current_version = match.group(1)
    new_version = bump_version(current_version, release_type)
    updated_text = re.sub(
        r"^version:\s*\S+\s*$",
        f"version: {new_version}",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    safe_pubspec_path.write_text(updated_text)
    return new_version


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pubspec", type=Path)
    parser.add_argument("release_type", choices=("major", "minor", "patch"))
    args = parser.parse_args()

    new_version = update_pubspec(args.pubspec, args.release_type)
    build_name = new_version.split("+", 1)[0]
    print(f"new_version={new_version}")
    print(f"build_name={build_name}")
    print(f"tag=v{build_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
