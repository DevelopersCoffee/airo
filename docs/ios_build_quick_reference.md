# iOS Build Quick Reference

## TL;DR - Current State

✅ **CocoaPods is still in use** via the checked-in [`app/ios/Podfile`](../app/ios/Podfile)  
✅ **Manual `pod install` is usually unnecessary** because Flutter runs the integration steps during normal iOS builds  
✅ **Xcode + CocoaPods must both be installed** on contributor machines

---

## Quick Start

### First Time Setup

```bash
# 1. Verify CocoaPods is installed
pod --version

# 2. Get dependencies
cd app
flutter pub get

# 3. Build
flutter build ios --simulator --debug --no-codesign
```

### Daily Development

```bash
# Clean build
flutter clean && flutter pub get

# Run on simulator
flutter run

# Run on device
flutter run -d <device-id>

# Build release
flutter build ios --release
```

---

## Common Commands

### List Devices

```bash
# iOS simulators
xcrun simctl list devices available | grep iPhone

# All Flutter devices
flutter devices
```

### Build Variants

```bash
# Debug build for simulator
flutter build ios --simulator --debug --no-codesign

# Release build for device
flutter build ios --release

# Profile build (for performance testing)
flutter build ios --profile
```

### Using Makefile

```bash
# Setup (verifies Xcode and CocoaPods are installed)
make setup-ios

# Build
make build-ios

# Optimize
make optimize-ios
```

---

## Troubleshooting

### "CocoaPods not installed" Warning

**This is not expected for the current repository state.** Install CocoaPods, then rerun the Flutter build.

### Build Fails

```bash
# Nuclear option - clean everything
flutter clean
rm -rf app/ios/Flutter/ephemeral/
flutter pub get
flutter build ios --simulator --debug --no-codesign
```

### Plugin Not Found

```bash
# Refresh Flutter and iOS dependencies
flutter pub get
cd ios && pod install && cd ..
```

---

## What NOT to Do

❌ **Don't delete `Podfile`** - it is part of the current iOS integration  
❌ **Don't commit generated `Pods/` artifacts** unless the repo policy changes  
❌ **Don't assume SPM-only setup** from older migration notes

---

## What TO Do

✅ **Run `flutter pub get`** after pulling changes  
✅ **Install CocoaPods once on your machine** before first iOS build
✅ **Use `flutter clean`** when switching branches  
✅ **Run `pod install` inside `app/ios` only when Flutter’s automatic integration fails**  
✅ **Report plugin issues** if something doesn't work

---

## File Locations

```
app/ios/
├── Podfile                    # CocoaPods integration used by Flutter
├── Runner.xcodeproj/          # Xcode project
├── Runner.xcworkspace/        # Workspace generated around CocoaPods integration
├── Runner/                    # App source code
├── Flutter/
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   └── ephemeral/             # Flutter-generated intermediate files
└── fastlane/                  # CI/CD scripts
```

---

## Need Help?

1. Check [iOS dependency status](./ios_spm_migration.md) for the current migration state
2. Check [iOS SPM Audit](./ios_spm_audit.md) for historical compatibility analysis
3. Ask in team chat
4. File an issue if it's a bug

---

**Last Updated**: June 21, 2026
