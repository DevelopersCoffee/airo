# iOS Dependency Management Status

## Summary

The attempted SPM-only migration is abandoned for now.

Airo cannot be built as an SPM-only Flutter iOS app today because the current plugin set still includes iOS plugins that ship and integrate through CocoaPods podspecs. The supported model is hybrid:

- Flutter may generate/use Swift Package Manager integration where the installed Flutter toolchain supports it.
- Flutter plugins that provide podspecs are still installed through CocoaPods.
- `pod install` remains part of the iOS setup/build workflow.

This document replaces the earlier "SPM migration complete" guidance. That guidance was incorrect for this repository.

## What changed from the abandoned experiment

The previous SPM-only notes claimed that:

- CocoaPods was gone.
- `pod install` was no longer needed.
- All Flutter plugins were managed through the generated SPM package.
- CocoaPods warnings could be ignored.

Those claims are no longer accepted as project guidance. For the current app, CocoaPods is required.

## Current source-of-truth build flow

From the repository root:

```bash
make setup-ios
make build-ios
```

Manual equivalent:

```bash
cd app
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
```

Simulator/debug builds can still use Flutter's normal commands after dependency setup:

```bash
cd app
flutter build ios --simulator --debug --no-codesign
flutter run -d ios
```

## Requirements

- macOS for iOS builds.
- Xcode command-line tools / Xcode.
- Flutter SDK matching this project.
- CocoaPods available as `pod`.

`make setup-ios` now validates both Xcode and CocoaPods before running dependency setup.

## Policy for dependency changes

Do:

- Keep `app/pubspec.yaml` as the complete application manifest.
- Run `flutter pub get` before CocoaPods commands.
- Run `pod install` in `app/ios` after iOS plugin/dependency changes.
- Keep `app/ios/Podfile` as the supported CocoaPods integration point.
- Treat generated SPM files under `app/ios/Flutter/ephemeral/` as generated Flutter state, not as proof that plugins no longer need CocoaPods.

Do not:

- Force SPM-only.
- Comment plugins out to avoid CocoaPods.
- Replace `app/pubspec.yaml` with a reduced iOS-only manifest.
- Use `app/pubspec_ios_spm.yaml` or `app/pubspec.yaml.backup` for normal builds.
- Copy dependency-management patterns from unrelated React Native projects; React Native projects that still run `pod install` are not evidence that this Flutter app can remove CocoaPods.

## Artifact cleanup decision

`app/pubspec_ios_spm.yaml` and `app/pubspec.yaml.backup` were reviewed as abandoned SPM-only experiment artifacts. They are not tracked on `main` and should not be added to version control.

If copies exist in a dirty local worktree, leave them unstaged or delete them only as part of local cleanup. They are intentionally not part of the supported repository state.

## Verification checklist

When changing iOS dependencies or build scripts:

1. `flutter pub get` succeeds in `app`.
2. `pod install` succeeds in `app/ios`.
3. A simulator build succeeds:

   ```bash
   cd app
   flutter build ios --simulator --debug --no-codesign
   ```

4. A release/device build is verified when signing and local tooling permit:

   ```bash
   cd app
   flutter build ios --release
   ```

5. Documentation does not claim that CocoaPods is gone or optional for the current plugin set.

## Related docs

- [iOS Build Quick Reference](./ios_build_quick_reference.md)
- [iOS SPM Audit](./ios_spm_audit.md)
