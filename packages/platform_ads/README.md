# Platform Ads (`airo_ads`)

[![pub package](https://img.shields.io/pub/v/airo_ads.svg)](https://pub.dev/packages/airo_ads)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Modular Google Mobile Ads SDK wrapper, in-app AdMob Native card widgets, frequency capping policy engine, and web/leanback/desktop opt-out guards for Flutter.

---

## ⚡ Features

- **Frequency Capping Engine (`AikaAdPolicy`)**:
  - Configurable session warmup (e.g. 5 minutes ad-free).
  - Configurable impression cooldown (e.g. 30 minutes between native card impressions).
  - Automatic web, TV leanback, and Chromecast stream denial rules.
- **Cross-Platform SDK Safety (`AikaAdSdk`)**:
  - Conditional imports ensuring web and desktop targets build without native FFI or missing plugin crashes.
- **In-App Native Card Widget (`AikaNativeAdCard`)**:
  - Dismissible AdMob Native Advanced card widget styled with Material 3 color schemes.
  - Zero interference with video playback or stream rendering.

---

## 🚀 Quick Start

### 1. Initialize Ad Manager

```dart
import 'package:platform_ads/platform_ads.dart';

await AikaAdManager.instance.initialize();
```

### 2. Embed Native Ad Card

```dart
import 'package:flutter/material.dart';
import 'package:platform_ads/platform_ads.dart';

class BrowseScreen extends StatelessWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        AikaNativeAdCard(
          placement: AikaAdPlacement.browse,
        ),
      ],
    );
  }
}
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
