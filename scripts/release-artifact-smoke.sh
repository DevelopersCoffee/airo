#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${AIRO_RELEASE_ARTIFACT_DIR:-$ROOT_DIR/release-artifacts}"
OUTPUT_DIR="${AIRO_RELEASE_QUALIFICATION_DIR:-$ROOT_DIR/artifacts/release-qualification/$(date -u +%Y%m%dT%H%M%SZ)}"
PACKAGE_NAME="${AIRO_ANDROID_PACKAGE:-io.airo.app}"
TV_PACKAGE_NAME="${AIRO_ANDROID_TV_PACKAGE:-io.airo.app.tv}"
REQUIRE_ARTIFACTS="${AIRO_REQUIRE_RELEASE_ARTIFACTS:-false}"
RUN_DEVICE_SMOKE="${AIRO_RUN_DEVICE_SMOKE:-false}"
RUN_WEB_SMOKE="${AIRO_RUN_WEB_SMOKE:-false}"

usage() {
  cat <<EOF
Usage: $0 [--artifact-dir DIR] [--output-dir DIR] [--require-artifacts]

Validates release artifacts with static integrity checks and optional local
device/web smoke checks.

Environment:
  AIRO_ANDROID_PACKAGE              Android package to launch, default io.airo.app
  AIRO_ANDROID_TV_PACKAGE           Android TV package, default io.airo.app.tv
  AIRO_REQUIRE_RELEASE_ARTIFACTS    true to fail when no artifacts are found
  AIRO_RUN_DEVICE_SMOKE             true to install/launch APKs through adb
  AIRO_RUN_WEB_SMOKE                true to serve web zip and run Playwright
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir)
      ARTIFACT_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --require-artifacts)
      REQUIRE_ARTIFACTS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/artifact-smoke-report.md"
JSONL="$OUTPUT_DIR/artifact-inventory.jsonl"
: > "$JSONL"

failures=0
warnings=0

record() {
  local status="$1"
  local kind="$2"
  local file="$3"
  local message="$4"
  local sha="${5:-}"
  python3 - "$status" "$kind" "$file" "$message" "$sha" >> "$JSONL" <<'PY'
import json
import sys

status, kind, file_path, message, sha = sys.argv[1:6]
print(json.dumps({
    "status": status,
    "kind": kind,
    "file": file_path,
    "message": message,
    "sha256": sha,
}, sort_keys=True))
PY
}

mark_fail() {
  failures=$((failures + 1))
  record "failed" "$1" "$2" "$3" "${4:-}"
  echo "::error::$3"
}

mark_warn() {
  warnings=$((warnings + 1))
  record "warning" "$1" "$2" "$3" "${4:-}"
  echo "::warning::$3"
}

mark_pass() {
  record "passed" "$1" "$2" "$3" "${4:-}"
}

sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

archive_test_zip() {
  unzip -t "$1" >/dev/null
}

archive_test_tar() {
  tar -tzf "$1" >/dev/null
}

android_device_available() {
  command -v adb >/dev/null 2>&1 &&
    adb devices | awk 'NR>1 && $2=="device" { found=1 } END { exit found?0:1 }'
}

smoke_android_apk() {
  local apk="$1"
  local package_name="$2"
  local label="$3"

  if [[ "$RUN_DEVICE_SMOKE" != "true" ]]; then
    mark_warn "$label" "$apk" "Skipped adb launch smoke; set AIRO_RUN_DEVICE_SMOKE=true to enable." "$(sha256 "$apk")"
    return
  fi

  if ! android_device_available; then
    mark_fail "$label" "$apk" "AIRO_RUN_DEVICE_SMOKE=true but no connected adb device is available." "$(sha256 "$apk")"
    return
  fi

  local base
  base="$(basename "$apk" .apk)"
  adb install -r "$apk" > "$OUTPUT_DIR/${base}-adb-install.log" 2>&1 ||
    { mark_fail "$label" "$apk" "adb install failed for $apk" "$(sha256 "$apk")"; return; }

  adb logcat -c || true
  adb shell am force-stop "$package_name" >/dev/null 2>&1 || true
  adb shell am start -W "$package_name/.MainActivity" > "$OUTPUT_DIR/${base}-launch.log" 2>&1 ||
    { adb logcat -d > "$OUTPUT_DIR/${base}-logcat.txt" || true; mark_fail "$label" "$apk" "adb launch failed for $package_name" "$(sha256 "$apk")"; return; }

  sleep 5
  adb shell screencap -p "/sdcard/${base}.png" >/dev/null 2>&1 || true
  adb pull "/sdcard/${base}.png" "$OUTPUT_DIR/${base}.png" >/dev/null 2>&1 || true
  adb logcat -d > "$OUTPUT_DIR/${base}-logcat.txt" || true

  if grep -E "FATAL EXCEPTION|AndroidRuntime|Process: ${package_name}" "$OUTPUT_DIR/${base}-logcat.txt" >/dev/null; then
    mark_fail "$label" "$apk" "Crash signature found in logcat after launching $package_name" "$(sha256 "$apk")"
    return
  fi

  mark_pass "$label" "$apk" "Installed and launched $package_name without startup crash." "$(sha256 "$apk")"
}

validate_apk() {
  local apk="$1"
  local sha
  sha="$(sha256 "$apk")"
  archive_test_zip "$apk" || { mark_fail "android_apk" "$apk" "APK zip integrity failed." "$sha"; return; }

  if unzip -l "$apk" | grep -q "AndroidManifest.xml"; then
    mark_pass "android_apk" "$apk" "APK integrity and manifest presence verified." "$sha"
  else
    mark_fail "android_apk" "$apk" "APK missing AndroidManifest.xml." "$sha"
    return
  fi

  if [[ "$(basename "$apk")" == *tv* ]]; then
    smoke_android_apk "$apk" "$TV_PACKAGE_NAME" "android_tv_apk"
  else
    smoke_android_apk "$apk" "$PACKAGE_NAME" "android_apk"
  fi
}

validate_aab() {
  local aab="$1"
  local sha
  sha="$(sha256 "$aab")"
  archive_test_zip "$aab" || { mark_fail "android_aab" "$aab" "AAB zip integrity failed." "$sha"; return; }
  if unzip -l "$aab" | grep -Eq "base/manifest/AndroidManifest.xml|base/manifest/.*AndroidManifest.xml"; then
    mark_pass "android_aab" "$aab" "AAB integrity and base manifest verified." "$sha"
  else
    mark_fail "android_aab" "$aab" "AAB missing base manifest." "$sha"
  fi
}

validate_ipa() {
  local ipa="$1"
  local sha
  sha="$(sha256 "$ipa")"
  archive_test_zip "$ipa" || { mark_fail "ios_ipa" "$ipa" "IPA zip integrity failed." "$sha"; return; }
  if unzip -l "$ipa" | grep -Eq "Payload/.+\\.app/Info.plist"; then
    mark_pass "ios_ipa" "$ipa" "IPA integrity and app Info.plist verified." "$sha"
  else
    mark_fail "ios_ipa" "$ipa" "IPA missing Payload/*.app/Info.plist." "$sha"
  fi
}

validate_macos_zip() {
  local zip="$1"
  local sha
  sha="$(sha256 "$zip")"
  archive_test_zip "$zip" || { mark_fail "macos_zip" "$zip" "macOS ZIP integrity failed." "$sha"; return; }

  if unzip -Z1 "$zip" | awk '
    /^[^\/]+\.app\/Contents\/Info\.plist$/ { has_info = 1 }
    /^[^\/]+\.app\/Contents\/MacOS\/[^\/]+$/ { has_executable = 1 }
    END { exit !(has_info && has_executable) }
  '; then
    mark_pass "macos_zip" "$zip" "macOS ZIP integrity and app bundle presence verified." "$sha"
  else
    mark_fail "macos_zip" "$zip" "macOS ZIP is missing an app bundle Info.plist or executable." "$sha"
  fi
}

validate_macos_dmg() {
  local dmg="$1"
  local sha
  sha="$(sha256 "$dmg")"

  if ! command -v hdiutil >/dev/null 2>&1; then
    mark_warn "macos_dmg" "$dmg" "Skipped DMG verification because hdiutil is unavailable on this host." "$sha"
    return
  fi

  if hdiutil verify "$dmg" >/dev/null; then
    mark_pass "macos_dmg" "$dmg" "macOS DMG integrity verified." "$sha"
  else
    mark_fail "macos_dmg" "$dmg" "macOS DMG integrity failed." "$sha"
  fi
}

validate_web_zip() {
  local zip="$1"
  local sha
  sha="$(sha256 "$zip")"
  archive_test_zip "$zip" || { mark_fail "web_zip" "$zip" "Web zip integrity failed." "$sha"; return; }
  if unzip -l "$zip" | grep -q "index.html"; then
    mark_pass "web_zip" "$zip" "Web archive integrity and index.html verified." "$sha"
  else
    mark_fail "web_zip" "$zip" "Web archive missing index.html." "$sha"
    return
  fi

  if [[ "$RUN_WEB_SMOKE" != "true" ]]; then
    mark_warn "web_zip" "$zip" "Skipped Playwright web artifact smoke; set AIRO_RUN_WEB_SMOKE=true to enable." "$sha"
    return
  fi

  local web_dir="$OUTPUT_DIR/web-smoke"
  rm -rf "$web_dir"
  mkdir -p "$web_dir"
  unzip -q "$zip" -d "$web_dir"
  (cd "$web_dir" && python3 -m http.server 8080 > "$OUTPUT_DIR/web-server.log" 2>&1 & echo $! > "$OUTPUT_DIR/web-server.pid")
  sleep 3
  if (cd "$ROOT_DIR/e2e" && FLUTTER_WEB_URL=http://127.0.0.1:8080 npx playwright test --grep "@smoke" --project=chromium --reporter=list); then
    mark_pass "web_zip" "$zip" "Playwright smoke passed against extracted web artifact." "$sha"
  else
    mark_fail "web_zip" "$zip" "Playwright smoke failed against extracted web artifact." "$sha"
  fi
  kill "$(cat "$OUTPUT_DIR/web-server.pid")" >/dev/null 2>&1 || true
}

validate_windows_zip() {
  local zip="$1"
  local sha
  sha="$(sha256 "$zip")"
  archive_test_zip "$zip" || { mark_fail "windows_zip" "$zip" "Windows zip integrity failed." "$sha"; return; }
  mark_pass "windows_zip" "$zip" "Windows archive integrity verified." "$sha"
}

validate_linux_tar() {
  local tarball="$1"
  local sha
  sha="$(sha256 "$tarball")"
  archive_test_tar "$tarball" || { mark_fail "linux_tar" "$tarball" "Linux tarball integrity failed." "$sha"; return; }
  mark_pass "linux_tar" "$tarball" "Linux archive integrity verified." "$sha"
}

declare -a artifacts
artifacts=()
while IFS= read -r artifact; do
  artifacts+=("$artifact")
done < <(find "$ARTIFACT_DIR" -type f \( \
  -name "*.apk" -o \
  -name "*.aab" -o \
  -name "*.ipa" -o \
  -name "*macOS.zip" -o \
  -name "*macOS.dmg" -o \
  -name "*web*.zip" -o \
  -name "*windows*.zip" -o \
  -name "*linux*.tar.gz" \
\) 2>/dev/null | sort)

if [[ "${#artifacts[@]}" -eq 0 ]]; then
  if [[ "$REQUIRE_ARTIFACTS" == "true" ]]; then
    mark_fail "artifact_discovery" "$ARTIFACT_DIR" "No release artifacts found in $ARTIFACT_DIR."
  else
    mark_warn "artifact_discovery" "$ARTIFACT_DIR" "No release artifacts found in $ARTIFACT_DIR."
  fi
fi

if [[ "${#artifacts[@]}" -gt 0 ]]; then
  for artifact in "${artifacts[@]}"; do
    case "$artifact" in
      *.apk) validate_apk "$artifact" ;;
      *.aab) validate_aab "$artifact" ;;
      *.ipa) validate_ipa "$artifact" ;;
      *macOS.zip) validate_macos_zip "$artifact" ;;
      *macOS.dmg) validate_macos_dmg "$artifact" ;;
      *web*.zip) validate_web_zip "$artifact" ;;
      *windows*.zip) validate_windows_zip "$artifact" ;;
      *linux*.tar.gz) validate_linux_tar "$artifact" ;;
      *) mark_warn "unknown" "$artifact" "Unrecognized artifact type." "$(sha256 "$artifact")" ;;
    esac
  done
fi

python3 - "$JSONL" "$REPORT" <<'PY'
import json
import sys

inventory_path, report_path = sys.argv[1:]
with open(inventory_path, encoding='utf-8') as inventory:
    records = [json.loads(line) for line in inventory if line.strip()]

lines = [
    '# Release Artifact Smoke Report',
    '',
    '| Status | Kind | Artifact | Result |',
    '| --- | --- | --- | --- |',
]
for record in records:
    message = record['message'].replace('|', '\\|')
    lines.append(
        f"| {record['status']} | {record['kind']} | {record['file']} | {message} |"
    )
lines.append('')
with open(report_path, 'w', encoding='utf-8') as report:
    report.write('\n'.join(lines))
PY

echo "Release artifact smoke report: $REPORT"

if [[ "$failures" -gt 0 ]]; then
  echo "Release artifact smoke failed: $failures failure(s), $warnings warning(s)." >&2
  exit 1
fi

echo "Release artifact smoke passed: $warnings warning(s)."
