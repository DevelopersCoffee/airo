#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

FAKE_ROOT="$TMP_DIR/repo"
FAKE_APP="$FAKE_ROOT/app"
FAKE_BIN="$TMP_DIR/bin"
mkdir -p "$FAKE_ROOT/scripts" "$FAKE_APP/android" "$FAKE_BIN"

cp "$ROOT_DIR/scripts/build-tv.sh" "$FAKE_ROOT/scripts/build-tv.sh"

cat >"$FAKE_ROOT/scripts/check-android-tv-release.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_ROOT/scripts/check-android-tv-release.sh"

cat >"$FAKE_BIN/flutter" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
  mkdir -p .dart_tool
  printf '%s\n' '{}' >.dart_tool/package_config.json
  printf '%s\n' 'resolved-by-tv-profile' >pubspec.lock
  exit 0
fi

if [[ "${1:-}" == "build" && "${2:-}" == "apk" ]]; then
  mkdir -p build/app/outputs/flutter-apk
  printf '%s\n' 'apk' >build/app/outputs/flutter-apk/app-release.apk
  exit 0
fi

echo "Unexpected flutter command: $*" >&2
exit 1
EOF
chmod +x "$FAKE_BIN/flutter"

printf '%s\n' 'name: full_profile' >"$FAKE_APP/pubspec.yaml"
printf '%s\n' 'name: tv_profile' >"$FAKE_APP/pubspec_tv.yaml"
printf '%s\n' 'locked-to-full-profile' >"$FAKE_APP/pubspec.lock"
printf '%s\n' 'storeFile=validation.keystore' >"$FAKE_APP/android/key.properties"

PATH="$FAKE_BIN:$PATH" bash "$FAKE_ROOT/scripts/build-tv.sh" --apk-only >/dev/null

grep -qx 'name: full_profile' "$FAKE_APP/pubspec.yaml"
grep -qx 'locked-to-full-profile' "$FAKE_APP/pubspec.lock"
[[ ! -e "$FAKE_APP/pubspec_backup.yaml" ]]
[[ ! -e "$FAKE_APP/pubspec_backup.lock" ]]

grep -q 'Copy-Item "pubspec.lock" "pubspec_backup.lock"' \
  "$ROOT_DIR/scripts/build-tv.ps1"
grep -q 'Copy-Item "pubspec_backup.lock" "pubspec.lock"' \
  "$ROOT_DIR/scripts/build-tv.ps1"

echo "TV profile restore tests passed"
