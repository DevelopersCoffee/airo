#!/usr/bin/env python3
"""Generate SHA256SUMS and a machine-readable v2 release manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROFILE_FILE = ROOT / ".github" / "airo-build-profiles.json"
RELEASE_EXTENSIONS = {".apk", ".aab", ".dmg", ".zip"}
MANIFEST_FILENAME = "Release-Manifest.json"
SHA256_FILENAME = "SHA256SUMS"


def error(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)


def load_profiles(path: Path) -> dict[str, dict]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    profiles = {}
    for profile in data.get("profiles", []):
        profile_id = profile.get("id")
        if profile_id:
            profiles[profile_id] = profile
    return profiles


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_under_root(path: Path, description: str) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(ROOT)
    except ValueError:
        error(f"{description} must be inside repository root: {resolved}")
        raise SystemExit(1)
    return resolved


def infer_profile_id(filename: str, profiles: dict[str, dict]) -> str | None:
    normalized = filename.lower().replace("_", "-")
    aliases = {
        "tv": ["airo-tv"],
        "full": ["airo", "airo-full", "full"],
    }
    for profile_id in profiles:
        candidates = aliases.get(profile_id, [profile_id])
        if any(candidate in normalized for candidate in candidates):
            return profile_id
    return None


def infer_artifact_type(path: Path) -> str:
    if path.suffix == ".apk":
        return "apk"
    if path.suffix == ".aab":
        return "aab"
    if path.suffix == ".dmg":
        return "macos_dmg"
    if path.suffix == ".zip" and "macos" in path.name.lower():
        return "macos_zip"
    return path.suffix.lstrip(".")


def infer_distribution_channel(path: Path) -> str:
    if path.suffix == ".aab":
        return "play-store"
    if path.suffix in {".dmg", ".zip"} and "macos" in path.name.lower():
        return "direct-macos"
    return "direct-apk"


def infer_abi(path: Path, profile: dict) -> str:
    filename = path.name.lower()
    if path.suffix in {".dmg", ".zip"} and "macos" in filename:
        if "arm64" in filename:
            return "macos-arm64"
        if "x64" in filename or "x86_64" in filename:
            return "macos-x64"
        return "macos-universal"
    if "arm64" in filename or "arm64-v8a" in filename:
        return "android-arm64"
    android = profile.get("android") or {}
    if android.get("abiStrategy") == "single-arm64-apk":
        return "android-arm64"
    if path.suffix == ".aab":
        return "play-managed"
    return "unknown"


def package_id_for_artifact(path: Path, profile: dict) -> str:
    if path.suffix in {".dmg", ".zip"} and "macos" in path.name.lower():
        macos = profile.get("macos") or {}
        return macos.get("bundleId") or profile.get("appId", "unknown")
    return profile.get("appId", "unknown")


def release_files(artifacts_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in artifacts_dir.iterdir()
        if path.is_file() and path.suffix.lower() in RELEASE_EXTENSIONS
    )


def write_sha256s(paths: list[Path], checksums: dict[str, str], output: Path) -> None:
    with output.open("w", encoding="utf-8") as handle:
        for path in paths:
            handle.write(f"{checksums[path.name]}  {path.name}\n")


def env_default(name: str, fallback: str) -> str:
    value = os.environ.get(name)
    return value if value else fallback


def build_manifest(args: argparse.Namespace) -> int:
    artifacts_dir = resolve_under_root(args.artifacts_dir, "Artifacts directory")
    if not artifacts_dir.is_dir():
        error(f"Artifacts directory does not exist: {artifacts_dir}")
        return 1

    profiles = load_profiles(resolve_under_root(args.profiles_file, "Build profiles file"))
    if args.profile_id and args.profile_id not in profiles:
        error(f"Unknown profile id: {args.profile_id}")
        return 1

    paths = release_files(artifacts_dir)
    if not paths and not args.allow_empty:
        error(f"No APK or AAB artifacts found in {artifacts_dir}")
        return 1

    checksums = {path.name: sha256_file(path) for path in paths}
    artifacts = []
    failures = 0

    for path in paths:
        profile_id = args.profile_id or infer_profile_id(path.name, profiles)
        if not profile_id:
            error(
                f"Cannot map artifact to a release profile: {path.name}. "
                "Pass --profile-id or use a profile-specific release filename."
            )
            failures += 1
            continue
        profile = profiles[profile_id]
        artifact = {
            "filename": path.name,
            "profileId": profile_id,
            "packageId": package_id_for_artifact(path, profile),
            "version": args.version,
            "buildNumber": args.build_number,
            "artifactType": infer_artifact_type(path),
            "abi": infer_abi(path, profile),
            "distributionChannel": infer_distribution_channel(path),
            "sizeBytes": path.stat().st_size,
            "sha256": checksums[path.name],
        }
        if artifact["artifactType"] in {"macos_dmg", "macos_zip"}:
            artifact["macos"] = {
                "signingStatus": args.macos_signing_status,
                "notarizationStatus": args.macos_notarization_status,
            }
        artifacts.append(artifact)

    if failures:
        return 1

    workflow_run_url = ""
    if args.repository and args.workflow_run:
        workflow_run_url = f"https://github.com/{args.repository}/actions/runs/{args.workflow_run}"

    manifest = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "release": {
            "version": args.version,
            "buildNumber": args.build_number,
            "sourceRef": args.source_ref,
            "sourceSha": args.source_sha,
            "workflowName": args.workflow_name,
            "workflowRun": args.workflow_run,
            "workflowRunAttempt": args.workflow_run_attempt,
            "workflowRunUrl": workflow_run_url,
        },
        "artifacts": artifacts,
    }

    output_manifest = artifacts_dir / MANIFEST_FILENAME
    output_sha256 = artifacts_dir / SHA256_FILENAME
    write_sha256s(paths, checksums, output_sha256)
    with output_manifest.open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"Wrote {output_sha256}")
    print(f"Wrote {output_manifest}")
    print(f"Release artifacts covered: {len(artifacts)}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate SHA256SUMS and a v2 release manifest for release artifacts."
    )
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    parser.add_argument("--profiles-file", type=Path, default=DEFAULT_PROFILE_FILE)
    parser.add_argument("--profile-id", help="Profile id for all artifacts in the directory.")
    parser.add_argument("--version", default=env_default("BUILD_NAME", env_default("RELEASE_VERSION", "unknown")))
    parser.add_argument("--build-number", default=env_default("BUILD_NUMBER", env_default("GITHUB_RUN_NUMBER", "unknown")))
    parser.add_argument("--source-ref", default=env_default("GITHUB_REF_NAME", env_default("GITHUB_REF", "unknown")))
    parser.add_argument("--source-sha", default=env_default("GITHUB_SHA", "unknown"))
    parser.add_argument("--workflow-name", default=env_default("GITHUB_WORKFLOW", "unknown"))
    parser.add_argument("--workflow-run", default=env_default("GITHUB_RUN_ID", "unknown"))
    parser.add_argument("--workflow-run-attempt", default=env_default("GITHUB_RUN_ATTEMPT", "unknown"))
    parser.add_argument("--repository", default=env_default("GITHUB_REPOSITORY", "DevelopersCoffee/airo"))
    parser.add_argument("--macos-signing-status", default=env_default("MACOS_SIGNING_STATUS", "unsigned"))
    parser.add_argument("--macos-notarization-status", default=env_default("MACOS_NOTARIZATION_STATUS", "not_notarized"))
    parser.add_argument("--allow-empty", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    sys.exit(build_manifest(parse_args()))
