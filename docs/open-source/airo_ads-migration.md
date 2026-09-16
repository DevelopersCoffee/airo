# Migration Record: `airo_ads`

> **Status**: Completed & Verified
> **Original Location**: `app/lib/aika_ads`
> **New Public Repository**: [DevelopersCoffee/airo_ads](https://github.com/DevelopersCoffee/airo_ads)
> **Consumed Remote Version**: `airo_ads: ^1.0.0` (pub.dev)

---

## 1. Migration Overview

1. Extracted Google Mobile Ads wrapper, AdMob Native cards, non-intrusive in-stream Pause Ads, lower-third overlays, VAST/VMAP ad tag parser, and pure Dart frequency policy engine from `app/lib/aika_ads` into standalone repository [`DevelopersCoffee/airo_ads`](https://github.com/DevelopersCoffee/airo_ads).
2. Published `airo_ads` `1.0.0` to pub.dev.
3. Added monorepo shim `packages/platform_ads` that re-exports `airo_ads`.
4. Replaced in-app source with `app/lib/aika_ads/aika_ads.dart` re-exporting the shim.

---

## 2. Monorepo Integration

In `packages/platform_ads/pubspec.yaml`:

```yaml
dependencies:
  airo_ads: ^1.0.0
```

In `packages/platform_ads/lib/platform_ads.dart`:

```dart
export 'package:airo_ads/airo_ads.dart';
```

In `app/lib/aika_ads/aika_ads.dart`:

```dart
export 'package:platform_ads/platform_ads.dart';
```

---

## 3. Verification

```bash
cd packages/platform_ads
flutter analyze
flutter test
```
