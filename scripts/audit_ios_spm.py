#!/usr/bin/env python3
"""Generate an iOS Swift Package Manager migration worksheet for the Flutter app."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PUBSPEC = REPO_ROOT / "app" / "pubspec.yaml"
DEFAULT_IOS_DIR = REPO_ROOT / "app" / "ios"
DEFAULT_OUTPUT = REPO_ROOT / "docs" / "ios_spm_audit.md"


LIKELY_IOS_NATIVE_PREFIXES = (
    "audio_",
    "camera",
    "connectivity_",
    "device_",
    "file_",
    "firebase_",
    "flutter_",
    "google_",
    "image_",
    "just_audio",
    "package_info_",
    "path_provider",
    "permission_",
    "share_",
    "shared_preferences",
    "sqlite3_flutter_libs",
    "url_launcher",
    "video_",
    "wakelock_",
)

HIGH_RISK_PLUGINS = {
    "firebase_auth": "FlutterFire plugin family often needs special handling during SPM migration.",
    "firebase_core": "FlutterFire plugin family often needs special handling during SPM migration.",
    "flutter_contacts": "Native contacts integration; verify package support before removing Pods.",
    "flutter_image_compress": "Native image compression plugin; verify SPM support explicitly.",
    "flutter_local_notifications": "Notification plugin touches native iOS capabilities and extensions.",
    "flutter_tts": "Text-to-speech plugin relies on native frameworks; confirm package manifest.",
    "google_mlkit_text_recognition": "ML Kit plugin family is a common migration risk due to native SDK packaging.",
    "google_sign_in": "Google Sign-In has native iOS SDK linkage and often needs explicit verification.",
    "image_picker": "Camera/photo library plugins commonly lag on packaging transitions.",
    "permission_handler": "Permission bridge plugin uses native iOS code and build settings.",
    "stockfish": "Less common plugin; niche packages are more likely to lack SPM support.",
    "video_player": "AVFoundation-based native plugin; verify package support explicitly.",
}

LIKELY_PURE_DART = {
    "chess",
    "dio",
    "drift",
    "equatable",
    "flame",
    "flame_audio",
    "go_router",
    "hive",
    "hive_flutter",
    "intl",
    "mocktail",
    "path",
    "riverpod",
    "flutter_riverpod",
    "riverpod_generator",
    "timezone",
    "uuid",
}


@dataclass
class Dependency:
    name: str
    source: str
    spec: str
    section: str

    @property
    def likely_ios_native(self) -> bool:
        if self.source != "hosted":
            return False
        if self.name in LIKELY_PURE_DART:
            return False
        return self.name.startswith(LIKELY_IOS_NATIVE_PREFIXES) or self.name in HIGH_RISK_PLUGINS

    @property
    def risk(self) -> str:
        if self.name in HIGH_RISK_PLUGINS:
            return "high"
        if self.likely_ios_native:
            return "medium"
        return "low"

    @property
    def notes(self) -> str:
        if self.name in HIGH_RISK_PLUGINS:
            return HIGH_RISK_PLUGINS[self.name]
        if self.source == "path":
            return "Local package. Audit its transitive plugins separately."
        if self.source == "sdk":
            return "Flutter SDK dependency."
        if self.likely_ios_native:
            return "Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly."
        return "Likely pure Dart or low-risk for iOS packaging."


def parse_pubspec(pubspec_path: Path) -> list[Dependency]:
    lines = pubspec_path.read_text().splitlines()
    section = None
    deps: list[Dependency] = []
    i = 0

    while i < len(lines):
        raw = lines[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*$", raw):
            top = raw.split(":", 1)[0]
            section = top if top in {"dependencies", "dev_dependencies"} else None
            i += 1
            continue

        if section and re.match(r"^  [A-Za-z0-9_]+:\s*.*$", raw):
            stripped = raw.strip()
            name, remainder = stripped.split(":", 1)
            remainder = remainder.strip()

            if remainder:
                deps.append(Dependency(name=name, source="hosted", spec=remainder, section=section))
                i += 1
                continue

            block: list[str] = []
            j = i + 1
            while j < len(lines):
                candidate = lines[j]
                if re.match(r"^  [A-Za-z0-9_]+:\s*.*$", candidate):
                    break
                if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*$", candidate):
                    break
                if candidate.startswith("    "):
                    block.append(candidate.strip())
                j += 1

            source = "hosted"
            spec = "block"
            for item in block:
                if item.startswith("sdk:"):
                    source = "sdk"
                    spec = item.split(":", 1)[1].strip()
                elif item.startswith("path:"):
                    source = "path"
                    spec = item.split(":", 1)[1].strip()
                elif item.startswith("git:"):
                    source = "git"
                    spec = item.split(":", 1)[1].strip()

            deps.append(Dependency(name=name, source=source, spec=spec, section=section))
            i = j
            continue

        i += 1

    return deps


def build_report(pubspec_path: Path, ios_dir: Path, dependencies: list[Dependency]) -> str:
    direct_deps = [dep for dep in dependencies if dep.section == "dependencies"]
    dev_deps = [dep for dep in dependencies if dep.section == "dev_dependencies"]
    hosted_direct = [dep for dep in direct_deps if dep.source == "hosted"]
    native_candidates = [dep for dep in hosted_direct if dep.likely_ios_native]
    local_packages = [dep for dep in direct_deps if dep.source == "path"]
    high_risk = [dep for dep in native_candidates if dep.risk == "high"]
    low_risk = [dep for dep in hosted_direct if not dep.likely_ios_native]

    podfile = ios_dir / "Podfile"
    workspace = ios_dir / "Runner.xcworkspace" / "contents.xcworkspacedata"
    package_manifest = ios_dir / "Flutter" / "ephemeral" / "Packages" / "FlutterGeneratedPluginSwiftPackage" / "Package.swift"

    lines: list[str] = []
    lines.append("# iOS SPM Migration Audit")
    lines.append("")
    lines.append(f"- Pubspec: `{pubspec_path}`")
    lines.append(f"- iOS directory: `{ios_dir}`")
    lines.append(f"- Podfile present: `{'yes' if podfile.exists() else 'no'}`")
    lines.append(f"- Runner workspace present: `{'yes' if workspace.exists() else 'no'}`")
    lines.append(f"- Generated Flutter SPM package present: `{'yes' if package_manifest.exists() else 'no'}`")
    lines.append("")
    lines.append("## Immediate findings")
    lines.append("")
    if not podfile.exists():
        lines.append("- `ios/Podfile` is missing. That means the current iOS scaffold is incomplete or already partially reworked.")
    if workspace.exists():
        lines.append("- `ios/Runner.xcworkspace` exists, but that alone does not prove Pods or SPM are configured.")
    if not package_manifest.exists():
        lines.append("- Flutter has not generated `FlutterGeneratedPluginSwiftPackage` in this checkout yet.")
    lines.append(f"- Direct app dependencies: `{len(direct_deps)}`")
    lines.append(f"- Hosted direct dependencies: `{len(hosted_direct)}`")
    lines.append(f"- Likely iOS-native plugin candidates: `{len(native_candidates)}`")
    lines.append(f"- High-risk plugin candidates: `{len(high_risk)}`")
    lines.append("")
    lines.append("## High-risk plugins to verify first")
    lines.append("")
    if high_risk:
        for dep in sorted(high_risk, key=lambda item: item.name):
            lines.append(f"- `{dep.name}`: {dep.notes}")
    else:
        lines.append("- None flagged.")
    lines.append("")
    lines.append("## Likely iOS-native plugin candidates")
    lines.append("")
    for dep in sorted(native_candidates, key=lambda item: item.name):
        lines.append(f"- `{dep.name}` ({dep.spec}): {dep.notes}")
    lines.append("")
    lines.append("## Likely pure-Dart or lower packaging risk")
    lines.append("")
    for dep in sorted(low_risk, key=lambda item: item.name):
        lines.append(f"- `{dep.name}` ({dep.spec})")
    lines.append("")
    lines.append("## Local packages")
    lines.append("")
    if local_packages:
        for dep in sorted(local_packages, key=lambda item: item.name):
            lines.append(f"- `{dep.name}` ({dep.spec}): {dep.notes}")
    else:
        lines.append("- None.")
    lines.append("")
    lines.append("## Dev dependencies")
    lines.append("")
    for dep in sorted(dev_deps, key=lambda item: item.name):
        lines.append(f"- `{dep.name}` [{dep.source}] ({dep.spec})")
    lines.append("")
    lines.append("## Recommended migration order")
    lines.append("")
    lines.append("1. Install and configure full Xcode on the Mac.")
    lines.append("2. Repair or regenerate the iOS scaffold so the app can build with the current dependency set.")
    lines.append("3. Enable Flutter SPM with `flutter config --enable-swift-package-manager`.")
    lines.append("4. Run `flutter pub get` and generate the Flutter-managed SPM package before editing Xcode.")
    lines.append("5. Verify the high-risk plugins above before attempting full CocoaPods removal.")
    lines.append("6. Expect mixed-mode SPM + CocoaPods until the remaining plugins are proven compatible.")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pubspec", type=Path, default=DEFAULT_PUBSPEC)
    parser.add_argument("--ios-dir", type=Path, default=DEFAULT_IOS_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    dependencies = parse_pubspec(args.pubspec)
    report = build_report(args.pubspec, args.ios_dir, dependencies)
    args.output.write_text(report)
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
