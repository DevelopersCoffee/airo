# macOS Cast architecture gap audit

Date: 2026-07-22

## Trigger

The macOS Airo TV app exposed the same Cast picker used by Pixel/iPad, but the
picker stayed at `Ready to search` / no receiver discovery on macOS.

## Finding

The Cast V1 implementation is a Google Cast sender path for Android and iOS.
The vendored `flutter_chrome_cast` plugin declares Android and iOS platforms
only, and the real controller rejects every other platform at runtime.

The macOS release contract already said Cast-only mobile behavior must be
hidden or no-op on macOS, but the app-level provider override always supplied
`FlutterChromeCastController` for every non-web platform. The feature screen
also rendered the Cast action for every non-web platform. That let macOS show a
mobile Cast affordance even though there was no macOS sender implementation.

## Architecture gap

Platform capability was inferred locally in UI and app wiring instead of being
declared as an executable product capability. Android/iOS fixes were validated
against Android/iOS sender flows, but the macOS build path had no regression
test enforcing the release contract.

## Process correction

- Treat Cast sender support as Android/iOS-only until a deliberate macOS Cast,
  AirPlay, or custom receiver implementation is designed.
- Keep macOS Cast behavior hidden or no-op.
- Add regression tests for both sides of the contract:
  - Android TV/mobile sender profiles wire a real Cast controller.
  - macOS wires an unavailable controller and hides the Cast toolbar action.
- Future Cast PRs must include a device/platform matrix note, not only a
  generic "works on mobile" statement.

## Source references

- Google Cast iOS permissions and discovery:
  https://developers.google.com/cast/docs/ios_sender/permissions_and_discovery
- Google Cast iOS sender integration:
  https://developers.google.com/cast/docs/ios_sender/integrate
- Apple Bonjour overview:
  https://developer.apple.com/bonjour/
- Apple local-network privacy guidance:
  https://developer.apple.com/videos/play/wwdc2020/10110/
- Local implementation:
  `packages/platform_player/lib/src/services/flutter_chrome_cast_controller.dart`
- Local plugin declaration:
  `packages/platform_player/third_party/flutter_chrome_cast/pubspec.yaml`
