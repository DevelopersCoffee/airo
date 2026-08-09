#!/usr/bin/env bash
# =============================================================================
# Android compileSdk / targetSdk baseline guard
# =============================================================================
# Fails when any in-repo Android module pins compileSdk (or an explicit
# targetSdk) below the repository baseline in gradle/libs.versions.toml.
#
# Why this exists (#1575): the root app module's compileSdk does not override
# Flutter plugin / package Android library modules. AGP validates each module
# against AAR metadata independently, so a package stuck on 35 fails the build
# even when app/ already uses 36.
#
# Usage: ./scripts/check-android-sdk-baseline.sh
# Exit 0 on success, 1 when drift is found or the catalog is unreadable.
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${AIRO_ANDROID_SDK_CATALOG:-$ROOT_DIR/gradle/libs.versions.toml}"
SCAN_ROOTS=("${AIRO_ANDROID_SDK_SCAN_ROOTS:-$ROOT_DIR/app:$ROOT_DIR/packages}")

fail() {
  echo "::error::$1" >&2
  exit 1
}

read_catalog_version() {
  local key="$1"
  local value
  value="$(sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([0-9]+)\"[[:space:]]*$/\\1/p" "$CATALOG" | head -1)"
  [[ -n "$value" ]] || fail "Missing ${key} in $CATALOG"
  printf '%s' "$value"
}

[[ -f "$CATALOG" ]] || fail "Android SDK catalog not found: $CATALOG"

BASELINE_COMPILE_SDK="$(read_catalog_version 'airo-compile-sdk')"
BASELINE_TARGET_SDK="$(read_catalog_version 'airo-target-sdk')"
APP_GRADLE="${AIRO_ANDROID_APP_GRADLE:-$ROOT_DIR/app/android/app/build.gradle.kts}"

echo "Airo Android SDK baseline (from $CATALOG):"
echo "  compileSdk >= $BASELINE_COMPILE_SDK"
echo "  targetSdk  >= $BASELINE_TARGET_SDK (when explicitly pinned)"
echo ""

# The app module must consume the catalog rather than re-pinning literals that
# can drift from gradle/libs.versions.toml independently.
if [[ -f "$APP_GRADLE" ]]; then
  grep -q 'libs.versions.airo.compile.sdk' "$APP_GRADLE" ||
    fail "App module must set compileSdk from gradle/libs.versions.toml (airo-compile-sdk)"
  grep -q 'libs.versions.airo.target.sdk' "$APP_GRADLE" ||
    fail "App module must set targetSdk from gradle/libs.versions.toml (airo-target-sdk)"
  grep -q 'libs.versions.airo.min.sdk' "$APP_GRADLE" ||
    fail "App module must set minSdk from gradle/libs.versions.toml (airo-min-sdk)"
  echo "✓ app module consumes version catalog for compileSdk/targetSdk/minSdk"
  echo ""
fi

IFS=':' read -r -a ROOTS <<< "${SCAN_ROOTS[0]}"

errors=0
checked=0

# Match `compileSdk = 35`, `compileSdk 36`, `compileSdkVersion 34`, etc.
# Ignore identifiers that only appear as variables (compileSdkVersion without a
# numeric assignment) — those are read from the configured android {} block.
scan_file() {
  local file="$1"
  local rel="${file#"$ROOT_DIR/"}"
  local line lineno sdk kind

  while IFS= read -r line; do
    lineno="${line%%:*}"
    content="${line#*:}"

    if [[ "$content" =~ (^|[[:space:]])compileSdk(Version)?[[:space:]]*=?[[:space:]]*([0-9]+) ]]; then
      sdk="${BASH_REMATCH[3]}"
      kind="compileSdk"
    elif [[ "$content" =~ (^|[[:space:]])targetSdk(Version)?[[:space:]]*=?[[:space:]]*([0-9]+) ]]; then
      sdk="${BASH_REMATCH[3]}"
      kind="targetSdk"
    else
      continue
    fi

    checked=$((checked + 1))
    local baseline="$BASELINE_COMPILE_SDK"
    if [[ "$kind" == "targetSdk" ]]; then
      baseline="$BASELINE_TARGET_SDK"
    fi

    if [[ "$sdk" -lt "$baseline" ]]; then
      echo "::error file=$rel,line=$lineno::$rel pins $kind=$sdk below repository baseline $baseline"
      errors=$((errors + 1))
    else
      echo "✓ $rel:$lineno $kind=$sdk"
    fi
  done < <(grep -nE '(^|[[:space:]])(compileSdk|targetSdk)(Version)?[[:space:]]*=?[[:space:]]*[0-9]+' "$file" || true)
}

shopt -s nullglob
for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' file; do
    # Cargokit plugin scaffolding talks about compileSdkVersion as a field type,
    # not an Android module pin — skip it.
    case "$file" in
      */cargokit/*) continue ;;
    esac
    scan_file "$file"
  done < <(find "$root" \( -name 'build.gradle' -o -name 'build.gradle.kts' \) -print0)
done
shopt -u nullglob

echo ""
if [[ "$checked" -eq 0 ]]; then
  fail "No compileSdk/targetSdk pins found under scan roots — catalog guard would be silent"
fi

if [[ "$errors" -gt 0 ]]; then
  echo ""
  echo "Found $errors Android SDK pin(s) below the repository baseline."
  echo "Update the module(s) or raise the baseline in gradle/libs.versions.toml together."
  echo "See #1575 — library modules are validated independently of the app module."
  exit 1
fi

echo "Android SDK baseline check passed ($checked pin(s) inspected)."
