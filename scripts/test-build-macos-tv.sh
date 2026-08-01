#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

TEST_ROOT="$TMP_ROOT/repo"
APP_DIR="$TEST_ROOT/app"
FAKE_BIN="$TMP_ROOT/bin"
mkdir -p \
  "$TEST_ROOT/scripts" \
  "$APP_DIR/macos/Flutter" \
  "$APP_DIR/linux/flutter" \
  "$APP_DIR/windows/flutter" \
  "$FAKE_BIN"

cp "$REPO_ROOT/scripts/build-macos-tv.sh" "$TEST_ROOT/scripts/build-macos-tv.sh"
printf '%s\n' 'full-profile' > "$APP_DIR/pubspec.yaml"
printf '%s\n' 'tv-profile' > "$APP_DIR/pubspec_tv.yaml"
printf '%s\n' 'full-lock' > "$APP_DIR/pubspec.lock"
printf '%s\n' 'stale-full-profile-pods' > "$APP_DIR/macos/Podfile.lock"
printf '%s\n' 'full-registrant' \
  > "$APP_DIR/macos/Flutter/GeneratedPluginRegistrant.swift"

cat > "$FAKE_BIN/uname" <<'SH'
#!/usr/bin/env bash
printf '%s\n' Darwin
SH

cat > "$FAKE_BIN/flutter" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$FAKE_FLUTTER_LOG"
case "${1:-} ${2:-}" in
  "pub get")
    grep -qx 'tv-profile' pubspec.yaml
    test ! -e macos/Podfile.lock
    ;;
  "analyze lib/main_tv.dart")
    grep -qx 'tv-profile' pubspec.yaml
    ;;
  "build macos")
    grep -qx 'tv-profile' pubspec.yaml
    test ! -e macos/Podfile.lock
    printf '%s\n' 'tv-profile-pods' > macos/Podfile.lock
    mkdir -p "build/macos/Build/Products/Release/Airo TV.app"
    ;;
  *)
    echo "unexpected flutter invocation: $*" >&2
    exit 1
    ;;
esac
SH

chmod +x \
  "$TEST_ROOT/scripts/build-macos-tv.sh" \
  "$FAKE_BIN/uname" \
  "$FAKE_BIN/flutter"

FAKE_FLUTTER_LOG="$TMP_ROOT/flutter.log" \
PATH="$FAKE_BIN:$PATH" \
BUILD_NAME=0.0.5 \
BUILD_NUMBER=5 \
  "$TEST_ROOT/scripts/build-macos-tv.sh"

grep -qx 'full-profile' "$APP_DIR/pubspec.yaml"
grep -qx 'full-lock' "$APP_DIR/pubspec.lock"
grep -qx 'stale-full-profile-pods' "$APP_DIR/macos/Podfile.lock"
grep -qx 'full-registrant' \
  "$APP_DIR/macos/Flutter/GeneratedPluginRegistrant.swift"
grep -qx 'pub get' "$TMP_ROOT/flutter.log"
grep -q '^analyze lib/main_tv.dart ' "$TMP_ROOT/flutter.log"
grep -q '^build macos ' "$TMP_ROOT/flutter.log"

test ! -e "$APP_DIR/pubspec.yaml.backup"
test ! -e "$APP_DIR/pubspec.lock.backup"
test ! -e "$APP_DIR/macos/Podfile.lock.backup"

echo "build-macos-tv tests passed"
