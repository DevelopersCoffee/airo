# Platform Ads

Monorepo shim that re-exports [`airo_ads`](https://pub.dev/packages/airo_ads).
Application code should import `package:platform_ads/platform_ads.dart` (or the
Aika Stream barrel `package:airo_app/aika_ads/aika_ads.dart`) rather than the
hosted package name.

```dart
import 'package:platform_ads/platform_ads.dart';

await AikaAdManager.instance.initialize();
```
