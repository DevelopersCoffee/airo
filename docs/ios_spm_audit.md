# iOS SPM Migration Audit

- Pubspec: `/Users/udaychauhan/workspace/airo/app/pubspec.yaml`
- iOS directory: `/Users/udaychauhan/workspace/airo/app/ios`
- Podfile present: `no`
- Runner workspace present: `yes`
- Generated Flutter SPM package present: `no`

## Immediate findings

- `ios/Podfile` is missing. That means the current iOS scaffold is incomplete or already partially reworked.
- `ios/Runner.xcworkspace` exists, but that alone does not prove Pods or SPM are configured.
- Flutter has not generated `FlutterGeneratedPluginSwiftPackage` in this checkout yet.
- Direct app dependencies: `50`
- Hosted direct dependencies: `42`
- Likely iOS-native plugin candidates: `23`
- High-risk plugin candidates: `12`

## High-risk plugins to verify first

- `firebase_auth`: FlutterFire plugin family often needs special handling during SPM migration.
- `firebase_core`: FlutterFire plugin family often needs special handling during SPM migration.
- `flutter_contacts`: Native contacts integration; verify package support before removing Pods.
- `flutter_image_compress`: Native image compression plugin; verify SPM support explicitly.
- `flutter_local_notifications`: Notification plugin touches native iOS capabilities and extensions.
- `flutter_tts`: Text-to-speech plugin relies on native frameworks; confirm package manifest.
- `google_mlkit_text_recognition`: ML Kit plugin family is a common migration risk due to native SDK packaging.
- `google_sign_in`: Google Sign-In has native iOS SDK linkage and often needs explicit verification.
- `image_picker`: Camera/photo library plugins commonly lag on packaging transitions.
- `permission_handler`: Permission bridge plugin uses native iOS code and build settings.
- `stockfish`: Less common plugin; niche packages are more likely to lack SPM support.
- `video_player`: AVFoundation-based native plugin; verify package support explicitly.

## Likely iOS-native plugin candidates

- `audio_service` (^0.18.18  # Latest version with SDK 36 compatibility): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `connectivity_plus` (7.0.0): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `file_picker` (10.3.10): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `firebase_auth` (6.1.4): FlutterFire plugin family often needs special handling during SPM migration.
- `firebase_core` (4.4.0): FlutterFire plugin family often needs special handling during SPM migration.
- `flutter_contacts` (1.1.9+2): Native contacts integration; verify package support before removing Pods.
- `flutter_image_compress` (2.4.0): Native image compression plugin; verify SPM support explicitly.
- `flutter_local_notifications` (19.5.0): Notification plugin touches native iOS capabilities and extensions.
- `flutter_tts` (4.2.5): Text-to-speech plugin relies on native frameworks; confirm package manifest.
- `google_mlkit_text_recognition` (0.15.1): ML Kit plugin family is a common migration risk due to native SDK packaging.
- `google_sign_in` (7.2.0): Google Sign-In has native iOS SDK linkage and often needs explicit verification.
- `image_picker` (1.2.1): Camera/photo library plugins commonly lag on packaging transitions.
- `just_audio` (^0.10.5): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `package_info_plus` (9.0.0): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `path_provider` (2.1.5): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `permission_handler` (12.0.0+1): Permission bridge plugin uses native iOS code and build settings.
- `share_plus` (^10.0.0): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `shared_preferences` (2.5.4): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `sqlite3_flutter_libs` (^0.5.41): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `stockfish` (1.8.1): Less common plugin; niche packages are more likely to lack SPM support.
- `url_launcher` (6.3.2): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.
- `video_player` (2.10.1): AVFoundation-based native plugin; verify package support explicitly.
- `wakelock_plus` (1.4.0): Looks like a Flutter plugin with native iOS code. Verify SPM support explicitly.

## Likely pure-Dart or lower packaging risk

- `audioplayers` (6.5.1)
- `cached_network_image` (3.4.1)
- `chess` (0.8.1)
- `cupertino_icons` (1.0.8)
- `dio` (5.9.1)
- `drift` (^2.18.0)
- `equatable` (2.0.8)
- `flame` (1.35.0)
- `flame_audio` (2.11.13)
- `flutter_riverpod` (2.6.1)
- `go_router` (17.1.0)
- `hive` (2.2.3)
- `hive_flutter` (1.1.0)
- `intl` (0.20.2)
- `path` (1.9.1)
- `riverpod` (2.6.1)
- `screenshot` (3.0.0)
- `timezone` (0.10.1)
- `uuid` (4.5.2)

## Local packages

- `airo` (../packages/airo): Local package. Audit its transitive plugins separately.
- `airomoney` (../packages/airomoney): Local package. Audit its transitive plugins separately.
- `core_ai` (../packages/core_ai): Local package. Audit its transitive plugins separately.
- `core_auth` (../packages/core_auth): Local package. Audit its transitive plugins separately.
- `core_data` (../packages/core_data): Local package. Audit its transitive plugins separately.
- `core_domain` (../packages/core_domain): Local package. Audit its transitive plugins separately.
- `core_ui` (../packages/core_ui): Local package. Audit its transitive plugins separately.

## Dev dependencies

- `alchemist` [hosted] (^0.13.0  # Golden testing (replaces discontinued golden_toolkit))
- `build_runner` [hosted] (2.4.13)
- `custom_lint` [hosted] (0.6.4)
- `drift_dev` [hosted] (^2.18.0)
- `flutter_lints` [hosted] (6.0.0)
- `flutter_test` [sdk] (flutter)
- `hive_generator` [hosted] (2.0.1)
- `integration_test` [sdk] (flutter)
- `mocktail` [hosted] (1.0.4)
- `patrol` [hosted] (^4.1.1  # E2E testing for iOS/Android devices (updated for compileSdk 34+ support))
- `riverpod_generator` [hosted] (2.4.0)
- `riverpod_lint` [hosted] (2.3.10)

## Recommended migration order

1. Install and configure full Xcode on the Mac.
2. Repair or regenerate the iOS scaffold so the app can build with the current dependency set.
3. Enable Flutter SPM with `flutter config --enable-swift-package-manager`.
4. Run `flutter pub get` and generate the Flutter-managed SPM package before editing Xcode.
5. Verify the high-risk plugins above before attempting full CocoaPods removal.
6. Expect mixed-mode SPM + CocoaPods until the remaining plugins are proven compatible.

