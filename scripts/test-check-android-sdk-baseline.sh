#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-android-sdk-baseline.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_case() {
  local name="$1"
  local expected_status="$2"
  shift 2

  set +e
  "$@" >"$TMP_DIR/$name.out" 2>&1
  local actual_status=$?
  set -e

  if [ "$expected_status" -ne "$actual_status" ]; then
    echo "FAIL: $name expected exit $expected_status, got $actual_status"
    cat "$TMP_DIR/$name.out"
    exit 1
  fi
}

# Fixture tree with a catalog + one good / one bad module.
fixture="$TMP_DIR/fixture"
mkdir -p "$fixture/gradle" "$fixture/app/android/app" "$fixture/packages/bad/android"

cat >"$fixture/gradle/libs.versions.toml" <<'EOF'
[versions]
airo-compile-sdk = "36"
airo-target-sdk = "36"
airo-min-sdk = "26"
EOF

cat >"$fixture/app/android/app/build.gradle.kts" <<'EOF'
android {
    compileSdk = libs.versions.airo.compile.sdk.get().toInt()
    defaultConfig {
        minSdk = libs.versions.airo.min.sdk.get().toInt()
        targetSdk = libs.versions.airo.target.sdk.get().toInt()
    }
}
EOF

# A separate scanned module still needs a numeric pin so the scanner is not silent.
mkdir -p "$fixture/packages/good/android"
cat >"$fixture/packages/good/android/build.gradle" <<'EOF'
android {
    compileSdk = 36
}
EOF

cat >"$fixture/packages/bad/android/build.gradle" <<'EOF'
android {
    compileSdk = 35
}
EOF

run_case "fails-on-drift" 1 \
  env AIRO_ANDROID_SDK_CATALOG="$fixture/gradle/libs.versions.toml" \
  AIRO_ANDROID_SDK_SCAN_ROOTS="$fixture/app:$fixture/packages" \
  AIRO_ANDROID_APP_GRADLE="$fixture/app/android/app/build.gradle.kts" \
  "$SCRIPT"
grep -q "compileSdk=35 below repository baseline 36" "$TMP_DIR/fails-on-drift.out"

# Align the bad module and confirm success.
cat >"$fixture/packages/bad/android/build.gradle" <<'EOF'
android {
    compileSdk = 36
}
EOF

run_case "passes-when-aligned" 0 \
  env AIRO_ANDROID_SDK_CATALOG="$fixture/gradle/libs.versions.toml" \
  AIRO_ANDROID_SDK_SCAN_ROOTS="$fixture/app:$fixture/packages" \
  AIRO_ANDROID_APP_GRADLE="$fixture/app/android/app/build.gradle.kts" \
  "$SCRIPT"
grep -q "Android SDK baseline check passed" "$TMP_DIR/passes-when-aligned.out"

# flutter.compileSdkVersion has no numeric pin — should not be treated as drift,
# but we still need at least one numeric pin in the tree.
cat >"$fixture/packages/bad/android/build.gradle" <<'EOF'
android {
    compileSdk = flutter.compileSdkVersion
}
EOF

run_case "passes-with-flutter-delegate" 0 \
  env AIRO_ANDROID_SDK_CATALOG="$fixture/gradle/libs.versions.toml" \
  AIRO_ANDROID_SDK_SCAN_ROOTS="$fixture/app:$fixture/packages" \
  AIRO_ANDROID_APP_GRADLE="$fixture/app/android/app/build.gradle.kts" \
  "$SCRIPT"

run_case "fails-without-catalog" 1 \
  env AIRO_ANDROID_SDK_CATALOG="$fixture/gradle/missing.toml" \
  AIRO_ANDROID_SDK_SCAN_ROOTS="$fixture/app" \
  AIRO_ANDROID_APP_GRADLE="$fixture/app/android/app/build.gradle.kts" \
  "$SCRIPT"

# App module that re-pins literals instead of consuming the catalog.
cat >"$fixture/app/android/app/build.gradle.kts" <<'EOF'
android {
    compileSdk = 36
    defaultConfig {
        minSdk = 26
        targetSdk = 36
    }
}
EOF

run_case "fails-when-app-skips-catalog" 1 \
  env AIRO_ANDROID_SDK_CATALOG="$fixture/gradle/libs.versions.toml" \
  AIRO_ANDROID_SDK_SCAN_ROOTS="$fixture/packages" \
  AIRO_ANDROID_APP_GRADLE="$fixture/app/android/app/build.gradle.kts" \
  "$SCRIPT"
grep -q "must set compileSdk from gradle/libs.versions.toml" "$TMP_DIR/fails-when-app-skips-catalog.out"

echo "check-android-sdk-baseline tests passed"
