## Plugin Compatibility Review - 2026-06-27

Issue: `#366` Review `flutter_contacts`, `package_info_plus`, `share_plus`, and `wakelock_plus` compatibility.

### Owning agent and scope

- Owner: Mobile Platform & UI Agent
- Supporting agents: CI/CD & Release Agent, QA & Testing Agent
- Layer: framework/platform integration review with minor dependency updates
- Impacted files:
  - `app/pubspec.yaml`
  - `app/pubspec_streaming.yaml`
  - `app/pubspec_tv.yaml`
  - `app/pubspec_ios_spm.yaml`

### Compatibility decisions

#### `wakelock_plus`

- Decision: pin to `1.5.2` and defer `1.6.x`
- Why: `1.6.1` now requires `package_info_plus ^10.1.0`, which exceeds the current repo baseline. `1.5.2` is the latest compatible line that resolves cleanly with `package_info_plus 9.0.1`.
- Repo impact: no code changes required; existing `WakelockPlus` usage remains valid.

#### `package_info_plus`

- Decision: keep on `9.0.1` and explicitly pin the latest compatible patch
- Why: `10.0.0` raises requirements beyond the current repo baseline, including Flutter `3.41.6`, iOS `13.0`, and macOS `10.15`.
- Repo impact: no API changes required; current `PackageInfo.fromPlatform()` usage remains valid.

#### `flutter_contacts`

- Decision: defer upgrade beyond `2.1.0`
- Why: `2.2.0` requires Flutter `3.44+`, which is above the repo baseline (`3.41.4`). The package also has TV/iOS-SPM stub coupling that would need a separate validation pass.
- Repo impact: current main app usage stays unchanged.

#### `share_plus`

- Decision: defer upgrade beyond `10.1.4`
- Why: newer lines add avoidable churn for this repo:
  - `11.0.0` introduces the `SharePlus` refactor.
  - `12.0.0` raises Android build requirements.
  - TV/iOS-SPM stub variants would also need coordinated validation.
- Repo impact: current `Share.share(...)` call sites remain untouched.

### Verification commands

```bash
cd app
flutter pub outdated --json
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test --reporter=compact test/features/iptv/domain/services/live_edge_detector_test.dart
```

### Verification results

- `flutter pub outdated --json`
  - confirmed newer `wakelock_plus` exists, but `1.6.x` is not compatible with the current `package_info_plus` / toolchain baseline
  - confirmed `package_info_plus 10.x` exists but exceeds current repo/toolchain baseline
  - confirmed `flutter_contacts 2.2.2` exists but repo remains on the latest compatible line
  - confirmed `share_plus 10.1.4` is the current repo line before the later refactor/build-floor changes
- `flutter pub get`
  - expected to refresh `app/pubspec.lock` with the explicit latest-compatible `wakelock_plus` / `package_info_plus` selections
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
  - validates that the safe bumps do not require source changes
- targeted IPTv test
  - validates the only direct `wakelock_plus` consumer path touched by dependency resolution

### Follow-ups

- If the team wants newer `share_plus`, split that into a dedicated migration ticket covering API updates plus TV/iOS-SPM stub validation.
- If the team wants newer `flutter_contacts`, first raise the workspace Flutter baseline to `3.44+`.
- If the team wants `package_info_plus 10.x`, first raise the workspace baseline to at least Flutter `3.41.6` and validate platform minimums.

### Official references

- https://pub.dev/packages/share_plus/changelog
- https://pub.dev/packages/flutter_contacts/changelog
- https://pub.dev/packages/package_info_plus/changelog
- https://pub.dev/packages/wakelock_plus/changelog
