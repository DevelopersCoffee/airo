#!/bin/bash
# Build script for Mobile Streaming APK (IPTV + Music, <150MB target)
# This script swaps pubspec.yaml with pubspec_streaming.yaml for the build

set -e

echo "Building Mobile Streaming APK..."

# Navigate to app directory
cd "$(dirname "$0")/../app"

# Cleanup function
cleanup() {
    echo ""
    echo "Restoring original pubspec.yaml..."
    if [ -f "pubspec.yaml.backup" ]; then
        cp "pubspec.yaml.backup" "pubspec.yaml"
        rm "pubspec.yaml.backup"
        echo "  Restored pubspec.yaml"
        
        # Restore original dependencies
        flutter pub get --offline 2>/dev/null || flutter pub get
        echo "  Dependencies restored"
    fi
}

# Set trap to ensure cleanup on exit
trap cleanup EXIT

# Backup original pubspec.yaml
echo "Swapping to streaming-specific pubspec (excludes games, OCR, keeps audio)..."
cp "pubspec.yaml" "pubspec.yaml.backup"
echo "  Backed up pubspec.yaml"

# Apply streaming-specific pubspec
cp "pubspec_streaming.yaml" "pubspec.yaml"
echo "  Applied pubspec_streaming.yaml"

# Clean and get dependencies
echo "Getting streaming dependencies..."
flutter pub get

# Build the APK with streaming entrypoint
echo "Building APK with streaming dependencies..."
flutter build apk --release \
    --target=lib/main_mobile_streaming.dart \
    --dart-define=APP_VARIANT=streaming \
    --dart-define=APP_PLATFORM=mobileStreaming \
    --split-per-abi \
    --tree-shake-icons \
    --obfuscate \
    --split-debug-info=build/debug-info-streaming

echo "Streaming APK created successfully!"
echo ""
echo "APK Sizes:"
for apk in build/app/outputs/flutter-apk/*.apk; do
    if [ -f "$apk" ]; then
        size=$(du -h "$apk" | cut -f1)
        echo "  $(basename "$apk"): $size"
    fi
done

echo ""
echo "Done!"

