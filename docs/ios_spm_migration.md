# iOS Dependency Integration Status

## Overview

This document records the attempted migration from CocoaPods to Swift Package Manager (SPM) for iOS dependency management in the Airo project and clarifies the current repository state.

**Status**: ⚠️ **Migration Not Completed** (repository still uses CocoaPods)

**Last Reviewed**: June 21, 2026

---

## Migration Summary

### Historical Migration Work

1. **Flutter SPM Support Enabled**: `flutter config --enable-swift-package-manager`
2. **SPM Package Generated**: `FlutterGeneratedPluginSwiftPackage` created in `app/ios/Flutter/ephemeral/Packages/`
3. **Workspace Updated**: `Runner.xcworkspace` now references the SPM package
4. **Makefile Updated**: Removed `pod install` commands from `setup-ios` target
5. **Dependencies Updated**: Fixed `meta` package version conflicts across all core packages

### Current Repository Reality

- `app/ios/Podfile` is committed and calls `flutter_install_all_ios_pods`
- The standard contributor path still depends on CocoaPods being installed locally
- Flutter may still generate SPM-related intermediate files, but they are not the source of truth for this repository
- Older docs that describe a completed SPM migration should be treated as historical notes, not current setup guidance

---

## Current State

### Signals That SPM Was Evaluated

1. **SPM Enabled**: Flutter was configured to experiment with Swift Package Manager support
2. **Package Generated**: Flutter generated an SPM package for these plugins at one point:
   - `firebase_core`, `firebase_auth`
   - `google_sign_in_ios`
   - `audio_service`, `just_audio`, `audioplayers_darwin`
   - `video_player_avfoundation`
   - `image_picker_ios`
   - `flutter_local_notifications`
   - `file_picker`, `share_plus`, `url_launcher_ios`
   - `path_provider_foundation`, `shared_preferences_foundation`
   - `sqlite3_flutter_libs`, `sqflite_darwin`
   - `connectivity_plus`, `wakelock_plus`, `package_info_plus`
   - `flutter_secure_storage_darwin`
   - `integration_test`

3. **Workspace Configured**: `Runner.xcworkspace/contents.xcworkspacedata` was updated during migration experiments

### Why The Migration Cannot Be Treated As Complete

1. **Checked-in Podfile**: The repository still contains a committed `Podfile`, not just ephemeral Flutter output.
2. **Current Setup Instructions**: iOS setup still has to account for CocoaPods on developer machines.
3. **Build Reliability**: Until iOS CI and local validation pass without CocoaPods, SPM-only guidance is misleading.

---

## Historical SPM Output

Flutter generated an SPM package during migration work. That does not override the current Podfile-based setup. The generated `Package.swift` looked like:

```swift
// Location: app/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [.iOS("13.0")],
    dependencies: [
        // 22 plugin packages managed by SPM
    ]
)
```

---

## Building the iOS App

### Prerequisites

- macOS with Xcode installed
- Flutter SDK 3.35.7+
- CocoaPods installed locally

### Build Commands

```bash
# Clean build artifacts
cd app
flutter clean

# Get dependencies
flutter pub get

# Build for simulator
flutter build ios --simulator --debug --no-codesign

# Build for device (requires code signing)
flutter build ios --release

# Run on simulator
flutter run -d <simulator-id>
```

### Using Makefile

```bash
# Setup iOS (verifies Xcode and CocoaPods are available)
make setup-ios

# Build iOS app
make build-ios
```

---

## Testing Instructions

### 1. Verify CocoaPods Tooling

```bash
pod --version
test -f app/ios/Podfile
```

### 2. Build on Simulator

```bash
# List available simulators
xcrun simctl list devices available | grep iPhone

# Build and run
cd app
flutter run -d <simulator-id>
```

### 3. Test on Physical Device (iPhone 13 Pro Max)

**Requirements**:
- iPhone 13 Pro Max running iOS 15.5+
- Apple Developer account with valid provisioning profile
- Device connected via USB or WiFi

**Steps**:

```bash
# 1. Connect device and verify it's detected
flutter devices

# 2. Build and deploy to device
cd app
flutter run -d <device-id>

# 3. Verify all features work:
#    - Firebase authentication
#    - Google Sign-In
#    - Audio playback (just_audio, audioplayers)
#    - Video playback
#    - Image picker
#    - Local notifications
#    - File picker
#    - Contacts access
#    - Camera/photo library
```

### 4. Verify Plugin Functionality

Test each high-risk plugin identified in the audit:

- [ ] **Firebase Auth**: Sign in/out, user session management
- [ ] **Google Sign-In**: OAuth flow, token refresh
- [ ] **Audio Service**: Background audio playback
- [ ] **Just Audio**: Music streaming, local playback
- [ ] **Video Player**: Video playback, controls
- [ ] **Image Picker**: Camera, photo library access
- [ ] **Flutter Local Notifications**: Schedule, display notifications
- [ ] **Flutter Contacts**: Read/write contacts
- [ ] **Permission Handler**: Request permissions (camera, photos, contacts, etc.)
- [ ] **ML Kit Text Recognition**: OCR functionality
- [ ] **Stockfish**: Chess engine integration

---

## Troubleshooting

### Issue: "CocoaPods not installed" Warning

**Symptom**: Build shows warning about CocoaPods not being installed

**Solution**: Install CocoaPods and rerun the build. For the current repository state, this warning should be treated as actionable.

### Issue: Build Fails with Missing Plugins

**Symptom**: Xcode build fails with "Module not found" errors

**Solution**:
```bash
# 1. Clean all build artifacts
flutter clean
rm -rf app/ios/Flutter/ephemeral/

# 2. Regenerate dependencies
flutter pub get

# 3. Verify SPM package was generated
ls app/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/

# 4. Rebuild
flutter build ios --simulator --debug --no-codesign
```

### Issue: Workspace Not Finding SPM Package

**Symptom**: Xcode can't find `FlutterGeneratedPluginSwiftPackage`

**Solution**: Verify workspace configuration includes SPM package reference:

```xml
<!-- app/ios/Runner.xcworkspace/contents.xcworkspacedata -->
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
   <FileRef location = "group:Runner.xcodeproj"></FileRef>
   <FileRef location = "group:Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage"></FileRef>
</Workspace>
```

### Issue: Plugin Not Working After Migration

**Symptom**: Specific plugin functionality broken after SPM migration

**Solution**:
1. Check plugin's SPM support in its `pubspec.yaml` and iOS implementation
2. Verify plugin is listed in `Package.swift`
3. Check for plugin-specific migration notes in its changelog
4. Consider filing an issue with the plugin maintainer if SPM support is missing

---

## Rollback Plan (If Needed)

If you need to rollback to CocoaPods:

```bash
# 1. Disable SPM
flutter config --no-enable-swift-package-manager

# 2. Clean build artifacts
flutter clean
rm -rf app/ios/Flutter/ephemeral/

# 3. Install CocoaPods (if not already installed)
sudo gem install cocoapods

# 4. Restore workspace to original state
# Edit app/ios/Runner.xcworkspace/contents.xcworkspacedata
# Remove the SPM package reference

# 5. Run pod install
cd app/ios
pod install

# 6. Build with CocoaPods
cd ..
flutter build ios
```

---

## References

- [Flutter SPM Documentation](https://docs.flutter.dev/packages-and-plugins/swift-package-manager)
- [iOS SPM Audit](./ios_spm_audit.md)
- [Flutter Issue Tracker - SPM Support](https://github.com/flutter/flutter/issues)
- [Apple SPM Documentation](https://developer.apple.com/documentation/xcode/swift-packages)

---

## Migration Checklist

- [x] Enable Flutter SPM support
- [x] Clean and regenerate dependencies
- [x] Verify SPM package generation
- [x] Update Makefile during the migration experiment
- [x] Update workspace configuration
- [x] Fix dependency version conflicts
- [ ] Test build on simulator (requires Xcode setup)
- [ ] Test on physical iPhone 13 Pro Max
- [ ] Verify all plugin functionality
- [ ] Update CI/CD pipelines (if applicable)
- [ ] Document any plugin-specific issues

---

## Next Steps

1. **Decide Source of Truth**: Either finish the SPM migration or explicitly standardize on CocoaPods for now
2. **Complete Testing**: Build and test on actual iOS devices to verify all plugins work correctly
3. **CI/CD Updates**: Update GitHub Actions only after iOS builds pass without CocoaPods
4. **Team Communication**: Notify team members that older SPM-only instructions are historical
5. **Update Documentation**: Keep this document aligned with the checked-in iOS integration files

---

**Status Maintained By**: Codex automation
**Last Updated**: June 21, 2026

