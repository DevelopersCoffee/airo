#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-android-tv-release.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_apk() {
  local apk="$1"
  local native_library="${2:-}"
  local root="$TMP_DIR/apk-root"
  rm -rf "$root"
  mkdir -p "$root/lib/arm64-v8a"
  if [[ -n "$native_library" ]]; then
    : >"$root/lib/arm64-v8a/$native_library"
  fi
  (cd "$root" && zip -qr "$apk" .)
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local registrant="$3"
  local apk="$4"

  set +e
  AIRO_TV_PLUGIN_REGISTRANT="$registrant" \
    AIRO_TV_RELEASE_APK="$apk" \
    "$SCRIPT" >"$TMP_DIR/$name.out" 2>&1
  local actual_status=$?
  set -e

  if [[ "$actual_status" -ne "$expected_status" ]]; then
    echo "FAIL: $name expected exit $expected_status, got $actual_status"
    cat "$TMP_DIR/$name.out"
    exit 1
  fi
}

good_registrant="$TMP_DIR/good-registrant.java"
cat >"$good_registrant" <<'EOF'
flutterEngine.getPlugins().add(new io.flutter.plugins.videoplayer.VideoPlayerPlugin());
EOF

bad_registrant="$TMP_DIR/bad-registrant.java"
cat >"$bad_registrant" <<'EOF'
flutterEngine.getPlugins().add(new io.flutter.plugins.videoplayer.VideoPlayerPlugin());
flutterEngine.getPlugins().add(new com.alexmercerind.media_kit_libs_android_video.MediaKitLibsAndroidVideoPlugin());
EOF

good_apk="$TMP_DIR/good.apk"
bad_apk="$TMP_DIR/bad.apk"
make_apk "$good_apk"
make_apk "$bad_apk" "libmpv.so"

run_case "accepts-video-player-only-contract" 0 "$good_registrant" "$good_apk"
run_case "rejects-media-kit-registration" 1 "$bad_registrant" "$good_apk"
grep -q "registrant includes media_kit" "$TMP_DIR/rejects-media-kit-registration.out"
run_case "rejects-excluded-native-library" 1 "$good_registrant" "$bad_apk"
grep -q "unexpectedly packages media_kit native libraries" "$TMP_DIR/rejects-excluded-native-library.out"

echo "Android TV native media contract tests passed"
