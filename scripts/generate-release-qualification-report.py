#!/usr/bin/env python3
"""Generate a v2 release qualification report from manifest and evidence JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_FILENAME = "Release-Qualification-Report.md"

PROFILE_REQUIREMENTS = {
    "full": [
        ("android-phone", "physical-device"),
        ("android-tablet", "wide-layout"),
    ],
    "tv": [
        ("android-tv", "physical-device"),
        ("fire-tv", "physical-device"),
    ],
}


def error(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)


def resolve_under_root(path: Path, description: str) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(ROOT)
    except ValueError:
        error(f"{description} must be inside repository root: {resolved}")
        raise SystemExit(1)
    return resolved


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def normalize(value: object) -> str:
    return str(value or "").strip().lower()


def is_apk(artifact: dict) -> bool:
    return normalize(artifact.get("artifactType")) == "apk" or str(artifact.get("filename", "")).endswith(".apk")


def find_check(checks: list[dict], artifact: dict, device_class: str, check_type: str) -> dict | None:
    for check in checks:
        if normalize(check.get("profileId")) != normalize(artifact.get("profileId")):
            continue
        if normalize(check.get("filename")) != normalize(artifact.get("filename")):
            continue
        if normalize(check.get("deviceClass")) != normalize(device_class):
            continue
        if normalize(check.get("checkType")) != normalize(check_type):
            continue
        if normalize(check.get("result")) == "passed":
            return check
    return None


def find_waiver(waivers: list[dict], artifact: dict, device_class: str) -> dict | None:
    for waiver in waivers:
        if normalize(waiver.get("profileId")) != normalize(artifact.get("profileId")):
            continue
        waiver_filename = normalize(waiver.get("filename"))
        if waiver_filename and waiver_filename != normalize(artifact.get("filename")):
            continue
        if normalize(waiver.get("deviceClass")) != normalize(device_class):
            continue
        if waiver.get("reason") and waiver.get("approvedBy"):
            return waiver
    return None


def row_for_artifact(
    artifact: dict,
    device_class: str,
    check_type: str,
    checks: list[dict],
    waivers: list[dict],
) -> tuple[dict, bool]:
    check = find_check(checks, artifact, device_class, check_type)
    if check:
        return (
            {
                "profile": artifact.get("profileId", ""),
                "package": artifact.get("packageId", ""),
                "artifact": artifact.get("filename", ""),
                "sha256": artifact.get("sha256", ""),
                "deviceClass": device_class,
                "requiredEvidence": check_type,
                "deviceModel": check.get("deviceModel", ""),
                "osVersion": check.get("osVersion", ""),
                "result": "passed",
                "notes": check.get("notes", ""),
            },
            True,
        )

    waiver = find_waiver(waivers, artifact, device_class)
    if waiver:
        return (
            {
                "profile": artifact.get("profileId", ""),
                "package": artifact.get("packageId", ""),
                "artifact": artifact.get("filename", ""),
                "sha256": artifact.get("sha256", ""),
                "deviceClass": device_class,
                "requiredEvidence": check_type,
                "deviceModel": "",
                "osVersion": "",
                "result": "waived",
                "notes": f"{waiver.get('reason')} Approved by {waiver.get('approvedBy')}.",
            },
            True,
        )

    return (
        {
            "profile": artifact.get("profileId", ""),
            "package": artifact.get("packageId", ""),
            "artifact": artifact.get("filename", ""),
            "sha256": artifact.get("sha256", ""),
            "deviceClass": device_class,
            "requiredEvidence": check_type,
            "deviceModel": "",
            "osVersion": "",
            "result": "missing",
            "notes": "No passing evidence or approved waiver.",
        },
        False,
    )


def markdown(rows: list[dict], mode: str) -> str:
    lines = [
        "# V2 Release Qualification Report",
        "",
        f"Mode: `{mode}`",
        "",
        "| Profile | Package | Artifact | SHA256 | Device class | Required evidence | Device model | OS version | Result | Notes |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in rows:
        checksum = str(row["sha256"])
        short_sha = checksum[:12] if checksum else ""
        values = [
            row["profile"],
            row["package"],
            row["artifact"],
            short_sha,
            row["deviceClass"],
            row["requiredEvidence"],
            row["deviceModel"],
            row["osVersion"],
            row["result"],
            row["notes"],
        ]
        escaped = [str(value).replace("|", "\\|").replace("\n", " ") for value in values]
        lines.append("| " + " | ".join(escaped) + " |")
    lines.append("")
    return "\n".join(lines)


def build_report(args: argparse.Namespace) -> int:
    manifest_path = resolve_under_root(args.manifest, "Release manifest")
    evidence_path = resolve_under_root(args.evidence, "Qualification evidence") if args.evidence else None
    output_path = manifest_path.parent / REPORT_FILENAME

    manifest = load_json(manifest_path)
    evidence = load_json(evidence_path) if evidence_path else {}
    checks = evidence.get("checks", [])
    waivers = evidence.get("waivers", [])

    rows = []
    missing = 0
    for artifact in manifest.get("artifacts", []):
        if not is_apk(artifact):
            continue
        requirements = PROFILE_REQUIREMENTS.get(str(artifact.get("profileId", "")), [])
        for device_class, check_type in requirements:
            row, satisfied = row_for_artifact(artifact, device_class, check_type, checks, waivers)
            rows.append(row)
            if not satisfied:
                missing += 1

    output_path.write_text(markdown(rows, args.mode), encoding="utf-8")
    print(f"Wrote {output_path}")
    print(f"Qualification rows: {len(rows)}")

    if args.mode == "public" and missing:
        error(f"Public qualification is missing {missing} required evidence row(s).")
        return 1
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate v2 release qualification report.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--mode", choices=("internal", "public"), default="internal")
    return parser.parse_args()


if __name__ == "__main__":
    sys.exit(build_report(parse_args()))
