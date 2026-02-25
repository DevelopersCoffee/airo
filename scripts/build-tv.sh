#!/bin/bash
# Build TV APK with lightweight dependencies
# This script swaps pubspec.yaml with pubspec_tv.yaml to exclude heavy dependencies
# Reduces APK size from ~145MB to ~28MB

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
FULL_BUILD=false
SKIP_RESTORE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full) FULL_BUILD=true; shift ;;
        --skip-restore) SKIP_RESTORE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "\033[0;34mBuilding Android TV APK...\033[0m"

cd "$APP_DIR"

if [ "$FULL_BUILD" = true ]; then
    echo -e "\033[0;33mBuilding with FULL dependencies (testing mode)...\033[0m"
    flutter build apk --release \
        --target=lib/main_tv.dart \
        --dart-define=APP_VARIANT=tv \
        --dart-define=APP_PLATFORM=androidTv \
        --split-per-abi \
        --tree-shake-icons
    echo -e "\033[0;32m✓ TV APK created (full dependencies)\033[0m"
    exit 0
fi

# Lightweight build - swap pubspec files
echo -e "\033[0;33mSwapping to TV-specific pubspec (excludes stockfish, flame, mlkit)...\033[0m"

# Backup original pubspec
if [ -f "pubspec.yaml" ]; then
    cp pubspec.yaml pubspec_backup.yaml
    echo "  Backed up pubspec.yaml"
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
}
trap cleanup EXIT

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

# Build APK
echo -e "\033[0;34mBuilding APK with reduced dependencies...\033[0m"
flutter build apk --release \
    --target=lib/main_tv.dart \
    --dart-define=APP_VARIANT=tv \
    --dart-define=APP_PLATFORM=androidTv \
    --split-per-abi \
    --tree-shake-icons

echo -e "\033[0;32m✓ TV APK created successfully!\033[0m"

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

echo -e "\n\033[0;32mDone!\033[0m"

