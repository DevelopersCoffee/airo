#!/bin/bash
# Build TV APK with lightweight dependencies
# This script swaps pubspec.yaml with pubspec_tv.yaml to exclude heavy dependencies
# Reduces APK size from ~145MB to ~28MB

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
ANDROID_DIR="$APP_DIR/android"
FULL_BUILD=false
SKIP_RESTORE=false
BUILD_AAB=true
BUILD_APK=true
SIGNING_CREATED=false

resolve_keytool() {
    if command -v keytool >/dev/null 2>&1; then
        local path_keytool
        path_keytool="$(command -v keytool)"
        if "$path_keytool" -help >/dev/null 2>&1; then
            printf '%s\n' "$path_keytool"
            return 0
        fi
    fi

    local flutter_jdk
    flutter_jdk="$(flutter config --list 2>/dev/null | sed -nE 's/^[[:space:]]*jdk-dir: (.+)$/\1/p' | head -1)"
    if [ -n "$flutter_jdk" ] && [ -x "$flutter_jdk/bin/keytool" ]; then
        printf '%s\n' "$flutter_jdk/bin/keytool"
        return 0
    fi

    for candidate in \
        /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/keytool \
        /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/keytool; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full) FULL_BUILD=true; shift ;;
        --skip-restore) SKIP_RESTORE=true; shift ;;
        --apk-only) BUILD_AAB=false; shift ;;
        --aab-only) BUILD_APK=false; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "\033[0;34mBuilding Android TV APK...\033[0m"

cd "$APP_DIR"

if [ ! -f "$ANDROID_DIR/key.properties" ]; then
    echo -e "\033[0;33mNo local Android signing config found; creating validation signing key...\033[0m"
    KEYTOOL_BIN="$(resolve_keytool)" || {
        echo -e "\033[0;31mERROR: keytool not found. Install JDK 17 or run flutter config --jdk-dir=<jdk>.\033[0m"
        exit 1
    }
    "$KEYTOOL_BIN" -genkeypair \
        -v \
        -keystore "$ANDROID_DIR/tv-validation.keystore" \
        -storepass tv-validation-password \
        -keypass tv-validation-password \
        -alias tv-validation \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=Airo TV Local Validation,O=DevelopersCoffee,C=US" >/dev/null 2>&1
    {
        echo "storeFile=tv-validation.keystore"
        echo "storePassword=tv-validation-password"
        echo "keyAlias=tv-validation"
        echo "keyPassword=tv-validation-password"
    } > "$ANDROID_DIR/key.properties"
    chmod 600 "$ANDROID_DIR/tv-validation.keystore" "$ANDROID_DIR/key.properties"
    SIGNING_CREATED=true
    echo "  Created ignored validation signing config"
fi

# Cleanup function
cleanup() {
    if [ "$SKIP_RESTORE" = false ] && [ -f "pubspec_backup.yaml" ]; then
        echo -e "\033[0;33mRestoring original pubspec.yaml...\033[0m"
        cp pubspec_backup.yaml pubspec.yaml
        rm -f pubspec_backup.yaml
        flutter pub get > /dev/null 2>&1
        echo "  Restored pubspec.yaml"
    fi
    if [ "$SIGNING_CREATED" = true ]; then
        rm -f "$ANDROID_DIR/key.properties" "$ANDROID_DIR/tv-validation.keystore"
        echo "  Removed validation signing config"
    fi
}
trap cleanup EXIT

if [ "$FULL_BUILD" = true ]; then
    echo -e "\033[0;33mBuilding with FULL dependencies (testing mode)...\033[0m"
    if [ "$BUILD_APK" = true ]; then
        flutter build apk --release \
            --target=lib/main_tv.dart \
            --dart-define=APP_VARIANT=tv \
            --dart-define=APP_PLATFORM=androidTv \
            --target-platform=android-arm64 \
            --tree-shake-icons
    fi
    if [ "$BUILD_AAB" = true ]; then
        flutter build appbundle --release \
            --target=lib/main_tv.dart \
            --dart-define=APP_VARIANT=tv \
            --dart-define=APP_PLATFORM=androidTv \
            --tree-shake-icons
    fi
    echo -e "\033[0;32m✓ TV artifacts created (full dependencies)\033[0m"
    exit 0
fi

# Lightweight build - swap pubspec files
echo -e "\033[0;33mSwapping to TV-specific pubspec (excludes stockfish, flame, mlkit)...\033[0m"

# Backup original pubspec
if [ -f "pubspec.yaml" ]; then
    cp pubspec.yaml pubspec_backup.yaml
    echo "  Backed up pubspec.yaml"
fi

# Swap to TV pubspec
if [ -f "pubspec_tv.yaml" ]; then
    cp pubspec_tv.yaml pubspec.yaml
    echo "  Applied pubspec_tv.yaml"
else
    echo -e "\033[0;31mERROR: pubspec_tv.yaml not found!\033[0m"
    exit 1
fi

# Get dependencies
echo -e "\033[0;34mGetting TV dependencies...\033[0m"
flutter pub get
if [ ! -f ".dart_tool/package_config.json" ]; then
    echo -e "\033[0;31mERROR: flutter pub get did not create .dart_tool/package_config.json\033[0m"
    exit 1
fi

# Build APK/AAB
if [ "$BUILD_APK" = true ]; then
    echo -e "\033[0;34mBuilding APK with reduced dependencies...\033[0m"
    flutter pub get >/dev/null
    flutter build apk --release \
        --target=lib/main_tv.dart \
        --dart-define=APP_VARIANT=tv \
        --dart-define=APP_PLATFORM=androidTv \
        --target-platform=android-arm64 \
        --tree-shake-icons \
        --split-debug-info=build/debug-info-tv \
        --obfuscate
fi

if [ "$BUILD_AAB" = true ]; then
    echo -e "\033[0;34mBuilding Play Store AAB with reduced dependencies...\033[0m"
    flutter pub get >/dev/null
    flutter build appbundle --release \
        --target=lib/main_tv.dart \
        --dart-define=APP_VARIANT=tv \
        --dart-define=APP_PLATFORM=androidTv \
        --tree-shake-icons \
        --split-debug-info=build/debug-info-tv \
        --obfuscate
fi

echo -e "\033[0;32m✓ TV artifacts created successfully!\033[0m"

release_apk=""
release_aab=""
if [ "$BUILD_APK" = true ]; then
    release_apk="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
fi
if [ "$BUILD_AAB" = true ]; then
    release_aab="$APP_DIR/build/app/outputs/bundle/release/app-release.aab"
fi

AIRO_TV_RELEASE_APK="$release_apk" \
AIRO_TV_RELEASE_AAB="$release_aab" \
  "$SCRIPT_DIR/check-android-tv-release.sh"

# Show APK sizes
APK_DIR="build/app/outputs/flutter-apk"
if [ -d "$APK_DIR" ]; then
    echo -e "\n\033[0;36mAPK Sizes:\033[0m"
    for apk in "$APK_DIR"/*-release.apk; do
        if [ -f "$apk" ]; then
            size=$(du -h "$apk" | cut -f1)
            echo "  $(basename "$apk"): $size"
        fi
    done
fi

AAB_DIR="build/app/outputs/bundle/release"
if [ -d "$AAB_DIR" ]; then
    echo -e "\n\033[0;36mAAB Sizes:\033[0m"
    for aab in "$AAB_DIR"/*-release.aab; do
        if [ -f "$aab" ]; then
            size=$(du -h "$aab" | cut -f1)
            echo "  $(basename "$aab"): $size"
        fi
    done
fi

echo -e "\n\033[0;32mDone!\033[0m"
