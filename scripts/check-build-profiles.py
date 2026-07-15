#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROFILE_FILE = ROOT / ".github" / "airo-build-profiles.json"
DEFAULT_BASELINE_FILE = ROOT / ".github" / "apk-size-baselines.tsv"
DEFAULT_REPORT_FILE = ROOT / "build-profile-report.md"
CI_WORKFLOW = ROOT / ".github" / "workflows" / "ci.yml"


def error(message, path=None):
    if path:
        print(f"::error file={path}::{message}")
    else:
        print(f"::error::{message}")


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def section_items(pubspec_text, section):
    lines = pubspec_text.splitlines()
    in_section = False
    items = {}
    current = None

    for raw in lines:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if not raw.startswith(" ") and raw.rstrip() == f"{section}:":
            in_section = True
            current = None
            continue
        if in_section and raw and not raw.startswith(" "):
            break
        if not in_section:
            continue

        stripped = raw.strip()
        if raw.startswith("  ") and not raw.startswith("    ") and ":" in stripped:
            key, value = stripped.split(":", 1)
            current = key.strip()
            items[current] = value.strip().strip("'\"")
            continue
        if current and raw.startswith("    ") and ":" in stripped:
            key, value = stripped.split(":", 1)
            if key.strip() == "path":
                items[current] = value.strip().strip("'\"")

    return items


def flutter_assets(pubspec_text):
    lines = pubspec_text.splitlines()
    in_flutter = False
    in_assets = False
    assets = []

    for raw in lines:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not raw.startswith(" ") and stripped == "flutter:":
            in_flutter = True
            in_assets = False
            continue
        if in_flutter and raw and not raw.startswith(" "):
            break
        if not in_flutter:
            continue
        if raw.startswith("  ") and not raw.startswith("    ") and stripped == "assets:":
            in_assets = True
            continue
        if in_assets and raw.startswith("  ") and not raw.startswith("    ") and stripped != "assets:":
            in_assets = False
        if in_assets and stripped.startswith("- "):
            assets.append(stripped[2:].strip().strip("'\""))

    return assets


def load_baselines(path):
    baselines = {}
    if not path.exists():
        return baselines
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("component\t"):
                continue
            parts = line.split("\t")
            if len(parts) >= 4:
                baselines[(parts[0], parts[1])] = {
                    "baseline_bytes": parts[2],
                    "budget_mb": parts[3],
                }
    return baselines


def normalize_path(value):
    return value.rstrip("/")


def main():
    profile_file = Path(os.environ.get("AIRO_BUILD_PROFILE_FILE", DEFAULT_PROFILE_FILE))
    baseline_file = Path(os.environ.get("AIRO_APK_BASELINE_FILE", DEFAULT_BASELINE_FILE))
    report_file = Path(os.environ.get("AIRO_BUILD_PROFILE_REPORT_FILE", DEFAULT_REPORT_FILE))

    profile_data = load_json(profile_file)
    shared_constraints = profile_data.get("sharedDependencyConstraints", {})
    baselines = load_baselines(baseline_file)
    ci_text = CI_WORKFLOW.read_text(encoding="utf-8") if CI_WORKFLOW.exists() else ""

    failures = 0
    rows = []
    required_top_level = [
        "id",
        "releaseLine",
        "entrypoint",
        "pubspec",
        "appVariant",
        "appPlatform",
        "requiredPackages",
        "featureModules",
    ]

    seen_ids = set()
    for profile in profile_data.get("profiles", []):
        profile_id = profile.get("id", "")
        status = "OK"
        notes = []

        if not profile_id or profile_id in seen_ids:
            error(f"Duplicate or missing profile id: {profile_id}", profile_file)
            failures += 1
            status = "FAIL"
        seen_ids.add(profile_id)

        for key in required_top_level:
            if key not in profile:
                error(f"{profile_id}: missing required field {key}", profile_file)
                failures += 1
                status = "FAIL"

        entrypoint = ROOT / profile.get("entrypoint", "")
        pubspec = ROOT / profile.get("pubspec", "")
        if not entrypoint.exists():
            error(f"{profile_id}: entrypoint does not exist: {entrypoint}", profile_file)
            failures += 1
            status = "FAIL"
        if not pubspec.exists():
            error(f"{profile_id}: pubspec does not exist: {pubspec}", profile_file)
            failures += 1
            status = "FAIL"
            rows.append((profile_id, "missing", "n/a", status, "pubspec missing"))
            continue

        pubspec_text = pubspec.read_text(encoding="utf-8")
        deps = section_items(pubspec_text, "dependencies")
        overrides = section_items(pubspec_text, "dependency_overrides")
        assets = flutter_assets(pubspec_text)

        for package in profile.get("requiredPackages", []):
            if package not in deps:
                error(f"{profile_id}: required package {package} missing from {pubspec}", pubspec)
                failures += 1
                status = "FAIL"

        for package, expected_constraint in shared_constraints.items():
            if package in deps and deps[package] != expected_constraint:
                error(
                    f"{profile_id}: {package} must use shared constraint {expected_constraint}, got {deps[package]}",
                    pubspec,
                )
                failures += 1
                status = "FAIL"

        for package, expected_path in profile.get("requiredDependencyOverrides", {}).items():
            actual_path = overrides.get(package)
            if normalize_path(actual_path or "") != normalize_path(expected_path):
                error(
                    f"{profile_id}: override for {package} must be {expected_path}, got {actual_path or 'missing'}",
                    pubspec,
                )
                failures += 1
                status = "FAIL"

        kgp_guarded = 0
        required_overrides = profile.get("requiredDependencyOverrides", {})
        for package in profile.get("legacyKotlinGradlePluginRiskPackages", []):
            if package not in deps:
                continue

            expected_path = required_overrides.get(package)
            if not expected_path:
                error(
                    f"{profile_id}: KGP-risk package {package} must be listed in requiredDependencyOverrides",
                    profile_file,
                )
                failures += 1
                status = "FAIL"
                continue

            if not normalize_path(expected_path).startswith("../packages/stubs/"):
                error(
                    f"{profile_id}: KGP-risk package {package} must use a packages/stubs override, got {expected_path}",
                    profile_file,
                )
                failures += 1
                status = "FAIL"

            if package not in overrides:
                error(
                    f"{profile_id}: KGP-risk package {package} must be stubbed/overridden in {pubspec}",
                    pubspec,
                )
                failures += 1
                status = "FAIL"
                continue

            kgp_guarded += 1

        for package in profile.get("heavyPackages", []):
            if package in deps and package not in overrides:
                error(f"{profile_id}: heavy package {package} is not stubbed/overridden", pubspec)
                failures += 1
                status = "FAIL"

        allowlist = profile.get("assetAllowlist", [])
        if allowlist:
            for asset in assets:
                if asset not in allowlist:
                    error(f"{profile_id}: asset {asset} is not in the profile allowlist", pubspec)
                    failures += 1
                    status = "FAIL"

        android = profile.get("android")
        if android:
            for key in ["apkArtifact", "abiStrategy", "releaseBudgetMb", "debugBudgetMb", "enforceReleaseBudget"]:
                if key not in android:
                    error(f"{profile_id}: android.{key} is required", profile_file)
                    failures += 1
                    status = "FAIL"
            if android.get("abiStrategy") not in {"single-arm64-apk", "split-per-abi", "app-bundle"}:
                error(f"{profile_id}: unsupported android.abiStrategy {android.get('abiStrategy')}", profile_file)
                failures += 1
                status = "FAIL"
            if android.get("enforceReleaseBudget"):
                key = (profile_id, android.get("apkArtifact", ""))
                baseline = baselines.get(key)
                if not baseline:
                    error(f"{profile_id}: missing APK size baseline for {key[1]}", baseline_file)
                    failures += 1
                    status = "FAIL"
                elif str(android.get("releaseBudgetMb")) != baseline["budget_mb"]:
                    error(
                        f"{profile_id}: profile budget {android.get('releaseBudgetMb')} does not match baseline budget {baseline['budget_mb']}",
                        baseline_file,
                    )
                    failures += 1
                    status = "FAIL"

        if profile.get("ciBuild") and android and f"name: {profile_id}" not in ci_text:
            error(f"{profile_id}: CI Android matrix does not reference this profile id", CI_WORKFLOW)
            failures += 1
            status = "FAIL"

        macos = profile.get("macos")
        if macos:
            for key in ["appName", "bundleId", "artifactZip", "artifactDmg", "distribution", "signing", "notarization"]:
                if key not in macos:
                    error(f"{profile_id}: macos.{key} is required", profile_file)
                    failures += 1
                    status = "FAIL"
            if macos.get("artifactZip") and not macos["artifactZip"].endswith(".zip"):
                error(f"{profile_id}: macos.artifactZip must end with .zip", profile_file)
                failures += 1
                status = "FAIL"
            if macos.get("artifactDmg") and not macos["artifactDmg"].endswith(".dmg"):
                error(f"{profile_id}: macos.artifactDmg must end with .dmg", profile_file)
                failures += 1
                status = "FAIL"

        if profile.get("edgeProfile"):
            notes.append(f"release <= {android.get('releaseBudgetMb')} MiB")
            notes.append(f"debug tracked <= {android.get('debugBudgetMb')} MiB")
            notes.append(f"{len(profile.get('heavyPackages', []))} heavy deps guarded")
            if profile.get("legacyKotlinGradlePluginRiskPackages"):
                notes.append(f"{kgp_guarded} KGP-risk deps guarded")
        else:
            notes.append("report only")

        rows.append(
            (
                profile_id,
                profile.get("releaseLine", "n/a"),
                profile.get("pubspec", "n/a"),
                status,
                "; ".join(notes),
            )
        )

    with report_file.open("w", encoding="utf-8") as handle:
        handle.write("## Airo Build Profile Contract\n\n")
        handle.write("| Profile | Release line | Pubspec | Status | Notes |\n")
        handle.write("|---------|--------------|---------|--------|-------|\n")
        for profile_id, release_line, pubspec, status, notes in rows:
            handle.write(f"| `{profile_id}` | {release_line} | `{pubspec}` | {status} | {notes} |\n")

    print(report_file.read_text(encoding="utf-8"))

    github_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if github_summary:
        with open(github_summary, "a", encoding="utf-8") as handle:
            handle.write(report_file.read_text(encoding="utf-8"))

    return failures


if __name__ == "__main__":
    sys.exit(main())
